namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;
using Microsoft.Service.Setup;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 25 document creation, repeat calls, scoping and late-error rollback.</summary>
codeunit 97785 "Svc Contr Job Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Contr Job Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_MonthlyInvoiceAdvancesDate()
    var
        Header: Record "Service Contract Header";
        Invoice: Record "Service Header";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // AC01: own January period is invoiced once for the monthly amount.
        Fixture.Create(Header);
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateInvoices", Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header));
        Response.Get('invoicesCreated', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One invoice reported.');
        Invoice.SetRange("Document Type", Invoice."Document Type"::Invoice);
        Invoice.SetRange("Customer No.", Header."Customer No.");
        Assert.AreEqual(1, Invoice.Count(), 'One unposted invoice.');
        Invoice.FindFirst();
        Invoice.CalcFields(Amount);
        Assert.AreEqual(100, Invoice.Amount, 'Monthly amount.');
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(DMY2Date(1, 2, 2026), Header."Next Invoice Date", 'Next period advanced.');
        Response := Invoke("Message Type ori"::"Service.Contract.CreateInvoices", Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header));
        Response.Get('invoicesCreated', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Repeat does not duplicate invoices.');
        Response.Get('contractsSkipped', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Repeat explains skipped contract.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC02_OrderContainsDueItemAndDoesNotDuplicate()
    var
        Header: Record "Service Contract Header";
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // AC02: only due contract items are added to preventive orders.
        Fixture.Create(Header);
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateServiceOrders", Fixture.Request("Message Type ori"::"Service.Contract.CreateServiceOrders", Header));
        Response.Get('serviceOrdersCreated', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One created order item.');
        ItemLine.SetRange("Contract No.", Header."Contract No.");
        ItemLine.FindFirst();
        Assert.AreEqual(Header."Customer No.", ItemLine."Service Item No.", 'Owned service item.');
        Response := Invoke("Message Type ori"::"Service.Contract.CreateServiceOrders", Fixture.Request("Message Type ori"::"Service.Contract.CreateServiceOrders", Header));
        Assert.AreEqual(1, ItemLine.Count(), 'No duplicate service item line.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC02_AddsLineToExistingPendingOrder()
    var
        Header: Record "Service Contract Header";
        Order: Record "Service Header";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // AC02 edge: existing pending order is reused and its new line reported separately.
        Fixture.Create(Header);
        Order."Document Type" := Order."Document Type"::Order;
        Order.Insert(true);
        Order.Validate("Customer No.", Header."Customer No.");
        Order."Contract No." := Header."Contract No.";
        Order.Modify();
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateServiceOrders", Fixture.Request("Message Type ori"::"Service.Contract.CreateServiceOrders", Header));
        Response.Get('serviceOrdersCreated', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'No new order.');
        Response.Get('linesAddedToExistingOrders', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Added line reported.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC03_CreditRetainsLineAndDoesNotDuplicate()
    var
        Header: Record "Service Contract Header";
        Line: Record "Service Contract Line";
        CreditMemo: Record "Service Header";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // AC03: credit the expired portion, retain contract lines and mark successful credit.
        Fixture.Create(Header);
        Fixture.PrepareCredit(Header);
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateCreditMemo", Fixture.Request("Message Type ori"::"Service.Contract.CreateCreditMemo", Header));
        Response.Get('creditMemos', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One credited line.');
        Line.Get(Header."Contract Type", Header."Contract No.", 10000);
        Assert.IsTrue(Line.Credited, 'Contract line retained and credited.');
        CreditMemo.SetRange("Document Type", CreditMemo."Document Type"::"Credit Memo");
        CreditMemo.SetRange("Customer No.", Header."Customer No.");
        Assert.AreEqual(1, CreditMemo.Count(), 'One unposted credit memo.');
        Response := Invoke("Message Type ori"::"Service.Contract.CreateCreditMemo", Fixture.Request("Message Type ori"::"Service.Contract.CreateCreditMemo", Header));
        Response.Get('creditMemos', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Credited line not credited twice.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC03_CreditWorksWhenContractSeriesStartBlank()
    var
        Header: Record "Service Contract Header";
        Setup: Record "Service Mgt. Setup";
        Response: JsonObject;
        Token: JsonToken;
        PriorInvoiceNos: Code[20];
        PriorCreditMemoNos: Code[20];
    begin
        // AC03 edge: a company without contract invoice or credit memo series still credits through owned fixture series.
        Setup.Get();
        PriorInvoiceNos := Setup."Contract Invoice Nos.";
        PriorCreditMemoNos := Setup."Contract Credit Memo Nos.";
        Setup."Contract Invoice Nos." := '';
        Setup."Contract Credit Memo Nos." := '';
        Setup.Modify();
        Fixture.Create(Header);
        Fixture.PrepareCredit(Header);
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateCreditMemo", Fixture.Request("Message Type ori"::"Service.Contract.CreateCreditMemo", Header));
        Response.Get('creditMemos', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Credit memo created from owned contract series.');
        Fixture.Cleanup();
        Setup.Get();
        Assert.AreEqual('', Setup."Contract Credit Memo Nos.", 'Cleanup restores the blank credit memo series.');
        Setup."Contract Invoice Nos." := PriorInvoiceNos;
        Setup."Contract Credit Memo Nos." := PriorCreditMemoNos;
        Setup.Modify();
    end;

    [Test]
    procedure Scenario_AC03_NoDueCreditLinesIsEmptySuccess()
    var
        Header: Record "Service Contract Header";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // AC03 edge: absent eligible credit dates produce no documents.
        Fixture.Create(Header);
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateCreditMemo", Fixture.Request("Message Type ori"::"Service.Contract.CreateCreditMemo", Header));
        Response.Get('creditMemos', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'No eligible credit.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC01_CustomerFilterDoesNotInvoiceOtherCustomer()
    var
        Header: Record "Service Contract Header";
        Other: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // AC01 bounded filters must never process another customer.
        Fixture.Create(Header);
        Fixture.Create(Other);
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header);
        Request.Remove('contractNos');
        Request.Add('customerNo', Header."Customer No.");
        Request.Add('nextInvoiceDateTo', '2026-01-31');
        Commit();
        Response := Invoke("Message Type ori"::"Service.Contract.CreateInvoices", Request);
        Other.Get(Other."Contract Type", Other."Contract No.");
        Assert.AreEqual(DMY2Date(1, 1, 2026), Other."Next Invoice Date", 'Other contract unchanged.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC05_LateNativeFailureRollsBackEveryWrite()
    var
        Header: Record "Service Contract Header";
        Document: Record "Service Header";
        Line: Record "Service Contract Line";
        Failure: Codeunit "Svc Contr Job Failure ori";
        TypeValue: Enum "Message Type ori";
        Response: JsonObject;
    begin
        // AC05: inject an error after native document writes, through the real dispatcher path.
        foreach TypeValue in Fixture.Types() do begin
            Fixture.Create(Header);
            if TypeValue = TypeValue::"Service.Contract.CreateCreditMemo" then
                Fixture.PrepareCredit(Header);
            Commit();
            BindSubscription(Failure);
            Response := Data.Invoke(TypeValue, Fixture.Request(TypeValue, Header), '', 1033, false);
            UnbindSubscription(Failure);
            Data.AssertRefusal(Response, 'BusinessCentralError');
            Document.SetRange("Customer No.", Header."Customer No.");
            Assert.IsTrue(Document.IsEmpty(), 'Native documents rolled back.');
            Header.Get(Header."Contract Type", Header."Contract No.");
            Assert.AreEqual(DMY2Date(1, 1, 2026), Header."Next Invoice Date", 'Period unchanged.');
            Line.Get(Header."Contract Type", Header."Contract No.", 10000);
            Assert.IsFalse(Line.Credited, 'Credit flag rolled back.');
            Fixture.Cleanup();
        end;
    end;

    [Test]
    procedure Scenario_AC05_SecondContractFailureRollsBackFirstInvoice()
    var
        Header: Record "Service Contract Header";
        Other: Record "Service Contract Header";
        Document: Record "Service Header";
        Numbers: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // AC05: a later contract cannot leave an earlier contract invoiced on batch failure.
        Fixture.Create(Header);
        Fixture.Create(Other);
        Other."Serv. Contract Acc. Gr. Code" := '';
        Other.Modify();
        Numbers.Add(Header."Contract No.");
        Numbers.Add(Other."Contract No.");
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header);
        Request.Replace('contractNos', Numbers);
        Request.Replace('expectedCount', 2);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Contract.CreateInvoices", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Document.SetRange("Customer No.", Header."Customer No.");
        Assert.IsTrue(Document.IsEmpty(), 'Earlier invoice rolled back.');
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(DMY2Date(1, 1, 2026), Header."Next Invoice Date", 'Earlier period unchanged.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC05_OmitCommitPreservesCallerRollback()
    var
        Header: Record "Service Contract Header";
        Document: Record "Service Header";
        Caller: Codeunit "Svc Contr Job Failure ori";
        TypeValue: Enum "Message Type ori";
        Ran: Boolean;
        FailureText: Text;
    begin
        // AC05: successful operations in a caller transaction roll back with the caller's error.
        foreach TypeValue in Fixture.Types() do begin
            Fixture.Create(Header);
            if TypeValue = TypeValue::"Service.Contract.CreateCreditMemo" then
                Fixture.PrepareCredit(Header);
            Caller.SetRequest(TypeValue, Fixture.Request(TypeValue, Header));
            Commit();
            ClearLastError();
            Ran := Caller.Run();
            FailureText := GetLastErrorText();
            Assert.IsFalse(Ran, 'Caller deliberately failed.');
            Assert.IsTrue(FailureText.Contains('X25-EXPECTED-CALLER-ROLLBACK'), FailureText);
            Document.SetRange("Customer No.", Header."Customer No.");
            Assert.IsTrue(Document.IsEmpty(), 'Caller rollback removed all documents.');
            Header.Get(Header."Contract Type", Header."Contract No.");
            Assert.AreEqual(DMY2Date(1, 1, 2026), Header."Next Invoice Date", 'Period rolled back with caller.');
            Fixture.Cleanup();
        end;
    end;

    local procedure Invoke(TypeValue: Enum "Message Type ori"; Request: JsonObject): JsonObject
    var
        Response: JsonObject;
        TextValue: Text;
    begin
        Response := Data.Invoke(TypeValue, Request, '', 1033, false);
        Response.WriteTo(TextValue);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), TextValue);
        exit(Response);
    end;
}
