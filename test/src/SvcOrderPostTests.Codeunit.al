namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Service.Document;
using Microsoft.Service.Ledger;
using Origo.Bifrost;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>Proves Service.Order.Post posts through standard Business Central service posting.</summary>
codeunit 97740 "Svc Order Post Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_ShipAndInvoice_PostsBothDocuments()
    var
        Header: Record "Service Header";
        LedgerEntry: Record "Service Ledger Entry";
        Response: JsonObject;
        LastEntry: Integer;
        OrderNo: Code[20];
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        if LedgerEntry.FindLast() then
            LastEntry := LedgerEntry."Entry No.";
        Response := PostData.Post(OrderNo, 'true', '', 'true', 1, 1033);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(Header."Customer No.", Data.TextValue(Response, 'customerNo'), 'The deleted order retains customer identity in the response.');
        Assert.AreEqual(Header.Name, Data.TextValue(Response, 'customerName'), 'The deleted order retains customer name in the response.');
        Assert.AreEqual(2, PostData.ArrayCount(Response, 'postedDocuments'), 'A shipment and an invoice are listed.');
        Assert.AreEqual(1, PostData.PostedShipments(OrderNo), 'One service shipment exists.');
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'One service invoice exists.');
        LedgerEntry.SetFilter("Entry No.", '>%1', LastEntry);
        LedgerEntry.SetRange("Service Order No.", OrderNo);
        Assert.AreEqual(LedgerEntry.Count(), PostData.IntegerValue(Response, 'serviceLedgerEntries'), 'The response counts the created ledger entries.');
        Assert.IsTrue(PostData.BooleanValue(Response, 'orderDeleted'), 'A fully posted order is removed by Business Central.');
        Assert.IsFalse(Header.Get(Header."Document Type"::Order, OrderNo), 'The order is gone.');
    end;

    [Test]
    procedure Scenario_AC02_ShipOnly_ThenInvoiceOnly()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        Response := PostData.Post(OrderNo, 'true', '', '', 1, 1033);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(1, PostData.ArrayCount(Response, 'postedDocuments'), 'Only a shipment is posted.');
        Assert.AreEqual(1, PostData.PostedShipments(OrderNo), 'One service shipment exists.');
        Assert.AreEqual(0, PostData.PostedInvoices(OrderNo), 'No invoice yet.');
        Line.SetRange("Document Type", Line."Document Type"::Order);
        Line.SetRange("Document No.", OrderNo);
        Line.SetFilter("Quantity Shipped", '>0');
        Assert.IsFalse(Line.IsEmpty(), 'Quantity Shipped is posted on the lines.');
        Response := PostData.Post(OrderNo, '', '', 'true', 1, 1033);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'The shipped quantity is invoiced.');
    end;

    [Test]
    procedure Scenario_AC02_Shipped_DefaultInvoice()
    begin
        InvoiceShippedOrder(false, false, 1033);
    end;

    [Test]
    procedure Scenario_AC02_Shipped_ExplicitInvoice()
    begin
        InvoiceShippedOrder(true, false, 1039);
    end;

    [Test]
    procedure Scenario_AC02_Shipped_MandatoryDefaultInvoice()
    begin
        InvoiceShippedOrder(false, true, 1039);
    end;

    [Test]
    procedure Scenario_AC02_Shipped_MandatoryExplicitInvoice()
    begin
        InvoiceShippedOrder(true, true, 1033);
    end;

    [Test]
    procedure Scenario_AC03_ShipAndConsume_NoInvoice()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Line.SetRange("Document Type", Line."Document Type"::Order);
        Line.SetRange("Document No.", OrderNo);
        Line.SetRange(Type, Line.Type::Item);
        Line.FindFirst();
        Line.Validate("Qty. to Consume", Line.Quantity);
        Line.Modify(true);
        Commit();
        Response := PostData.Post(OrderNo, 'true', 'true', '', 1, 1033);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(0, PostData.PostedInvoices(OrderNo), 'Consumption posts no invoice.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(Line.Quantity, Line."Quantity Consumed", 'Quantity Consumed is posted.');
    end;

    [Test]
    procedure Scenario_AC04_PartialQuantity_OrderStays()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Line.SetRange("Document Type", Line."Document Type"::Order);
        Line.SetRange("Document No.", OrderNo);
        Line.SetRange(Type, Line.Type::Resource);
        Line.FindFirst();
        Line.Validate("Qty. to Ship", 1);
        Line.Modify(true);
        Commit();
        Response := PostData.Post(OrderNo, 'true', '', '', 1, 1033);
        PostData.AssertSuccess(Response);
        Assert.IsFalse(PostData.BooleanValue(Response, 'orderDeleted'), 'A partly shipped order stays.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(1, Line."Quantity Shipped", 'One unit is shipped.');
    end;

    [Test]
    procedure Scenario_AC05_NoFlags_DefaultsToShipAndInvoice()
    var
        Header: Record "Service Header";
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        Response := PostData.Post(OrderNo, '', '', '', 1, 1033);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(1, PostData.PostedShipments(OrderNo), 'Default posts the shipment.');
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'Default posts the invoice.');
    end;

    [Test]
    procedure Scenario_AC05_ConsumeWithInvoice_Refused()
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Response := PostData.Post(Header."No.", 'true', 'true', 'true', 1, 1033);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Nothing is posted.');
    end;

    [Test]
    procedure Scenario_AC05_ConsumeWithoutShip_Refused()
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Response := PostData.Post(Header."No.", '', 'true', '', 1, 1033);
        Data.AssertRefusal(Response, 'InvalidParameter');
    end;

    [Test]
    procedure Scenario_AC06_NothingToPost_PreconditionFailed()
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        PostData.SetQuantities(Header, 0, 0, 0);
        Response := PostData.Post(Header."No.", 'true', '', '', 1, 1033);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Nothing is posted.');
    end;

    [Test]
    procedure Scenario_AC06_InvoiceBeforeShipment_PreconditionFailed()
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        // Story #7 AC06 | Time: WorkDate for posting | Risk: None.
        PostData.CreateOrder(Header);
        Commit();
        Response := PostData.Post(Header."No.", '', '', 'true', 1, 1033);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(0, PostData.PostedInvoices(Header."No."), 'There is no shipped quantity to invoice.');
    end;

    [Test]
    procedure Scenario_AC07_PolicyProhibitsInvoice_PreconditionFailed()
    var
        Header: Record "Service Header";
        UserSetup: Record "User Setup";
        Existed: Boolean;
        OldPolicy: Enum "Invoice Posting Policy";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Existed := UserSetup.Get(UserId());
        if not Existed then begin
            UserSetup.Init();
            UserSetup."User ID" := CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"));
            UserSetup.Insert();
        end;
        OldPolicy := UserSetup."Service Invoice Posting Policy";
        UserSetup."Service Invoice Posting Policy" := UserSetup."Service Invoice Posting Policy"::Prohibited;
        UserSetup.Modify();
        Commit();
        Response := PostData.Post(Header."No.", 'true', '', 'true', 1, 1033);
        if Existed then begin
            UserSetup."Service Invoice Posting Policy" := OldPolicy;
            UserSetup.Modify();
        end else
            UserSetup.Delete();
        Commit();
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(0, PostData.PostedInvoices(Header."No."), 'Nothing is posted.');
    end;

    [Test]
    procedure Scenario_AC07_Mandatory_InvoiceOnlyRefused()
    var
        Header: Record "Service Header";
        UserSetup: Record "User Setup";
        OldPolicy: Enum "Invoice Posting Policy";
        Response: JsonObject;
        Serialized: Text;
        Existed: Boolean;
    begin
        // Story #7 AC07 | Time: WorkDate for service posting | Risk: own user policy is restored after the call.
        PostData.CreateOrder(Header);
        Commit();
        Response := PostData.Post(Header."No.", 'true', '', '', 1, 1033);
        PostData.AssertSuccess(Response);
        Existed := UserSetup.Get(UserId());
        if not Existed then begin
            UserSetup.Init();
            UserSetup."User ID" := CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"));
            UserSetup.Insert();
        end;
        OldPolicy := UserSetup."Service Invoice Posting Policy";
        UserSetup."Service Invoice Posting Policy" := UserSetup."Service Invoice Posting Policy"::Mandatory;
        UserSetup.Modify();
        Commit();
        Response := PostData.Post(Header."No.", '', '', 'true', 1, 1033);
        if Existed then begin
            UserSetup."Service Invoice Posting Policy" := OldPolicy;
            UserSetup.Modify();
        end else
            UserSetup.Delete();
        Commit();
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('Mandatory'), 'The refusal names the actual posting policy.');
        Assert.AreEqual(0, PostData.PostedInvoices(Header."No."), 'Mandatory requires Ship and Invoice, as in the native menu.');
    end;

    [Test]
    procedure Scenario_AC08_BcRefusal_AtomicBusinessCentralError()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        // A closed posting date range makes Business Central refuse the posting after the request is validated.
        Header.Validate("Posting Date", 20000101D);
        Header.Modify(true);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.FindFirst();
        Line.Validate("Posting Date", 20000101D);
        Line.Modify(true);
        SetAllowedRange(20260101D, 20261231D);
        Commit();
        Response := PostData.Post(Header."No.", 'true', '', 'true', 1, 1033);
        SetAllowedRange(0D, 0D);
        Commit();
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'No shipment exists after the refusal.');
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'The order is unchanged.');
    end;

    [Test]
    procedure Scenario_AC12_NonBooleanFlag_InvalidParameterFormat()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Request.Add('no', Header."No.");
        Request.Add('ship', 'yes');
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
    end;

    [Test]
    procedure Scenario_AC12_TwoBadFlags_MultipleErrors()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Request.Add('no', Header."No.");
        Request.Add('ship', 'yes');
        Request.Add('invoice', 3);
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'MultipleErrors');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Nothing is posted.');
    end;

    [Test]
    procedure Scenario_AC12_MissingIdentifier_MissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'MissingParameter');
    end;

    [Test]
    procedure Scenario_AC12_UnknownKey_FoundationRefuses()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Request.Add('no', Header."No.");
        Request.Add('ship', true);
        Request.Add('extra', 'x');
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'UnknownParameter');
    end;

    [Test]
    procedure Scenario_AC13_FailedCall_LeavesNothingPosted()
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        PostData.SetQuantities(Header, 0, 0, 0);
        Response := PostData.Post(Header."No.", 'true', '', 'true', 1, 1033);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No.") + PostData.PostedInvoices(Header."No."), 'A failing call leaves nothing posted.');
    end;

    [Test]
    procedure Scenario_AC13_OmitCommit_NativeErrorRollsBack()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Request: JsonObject;
        Response: JsonObject;
        ErrorText: Text;
    begin
        // Story #7 AC13 | Time: closed posting range in2026 | Risk: native Omit Commit errors propagate, as in Warehouse.
        PostData.CreateOrder(Header);
        Header.Validate("Posting Date", 20000101D);
        Header.Modify(true);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.FindSet(true);
        repeat
            Line.Validate("Posting Date", 20000101D);
            Line.Modify(true);
        until Line.Next() = 0;
        SetAllowedRange(20260101D, 20261231D);
        Request := PostData.Build(Header."No.", 'true', '', 'true', 1);
        Commit();
        asserterror Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, true);
        ErrorText := GetLastErrorText();
        SetAllowedRange(0D, 0D);
        Commit();
        Assert.IsTrue(ErrorText.Contains('Posting Date'), 'The original native posting-date refusal must propagate.');
        Assert.IsFalse(ErrorText.Contains('transaction'), 'The native refusal must not become a Codeunit.Run transaction failure.');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No.") + PostData.PostedInvoices(Header."No."), 'A failed chained post leaves no posted documents.');
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'The refused order remains.');
    end;

    [Test]
    procedure Scenario_AC13_OmitCommit_PostSurvivesCallerRollback()
    var
        Header: Record "Service Header";
        Caller: Codeunit "Svc Post Caller Rollback ori";
        OrderNo: Code[20];
    begin
        // Story #7 AC13 | Time: WorkDate for posting | Risk: standard Service-Post commits are intentionally retained.
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        asserterror Caller.Run(Header);
        Assert.ExpectedError('X-SVC7-EXPECTED-CALLER-ROLLBACK');
        Assert.AreEqual(1, PostData.PostedShipments(OrderNo), 'The native committed shipment survives the later caller error.');
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'The native committed invoice survives Omit Commit and the caller error.');
        Assert.IsFalse(Header.Get(Header."Document Type"::Order, OrderNo), 'The fully posted order stays deleted.');
    end;

    local procedure SetAllowedRange(FromDate: Date; ToDate: Date)
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        GeneralLedgerSetup.Get();
        GeneralLedgerSetup."Allow Posting From" := FromDate;
        GeneralLedgerSetup."Allow Posting To" := ToDate;
        GeneralLedgerSetup.Modify();
    end;
    local procedure InvoiceShippedOrder(ExplicitFlags: Boolean; MandatoryPolicy: Boolean; Lcid: Integer)
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        UserSetup: Record "User Setup";
        OldPolicy: Enum "Invoice Posting Policy";
        Response: JsonObject;
        Preview: JsonObject;
        OrderNo: Code[20];
        ShipFlag: Text;
        InvoiceFlag: Text;
        Existed: Boolean;
    begin
        // Story #7 AC02/AC07/AC11 | Time: WorkDate | Risk: restore the owned user's posting policy.
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        Response := PostData.Post(OrderNo, 'true', '', '', 1, Lcid);
        PostData.AssertSuccess(Response);
        Line.SetRange("Document Type", Line."Document Type"::Order);
        Line.SetRange("Document No.", OrderNo);
        Line.SetFilter("Qty. to Ship", '<>0');
        Assert.IsTrue(Line.IsEmpty(), 'All quantities have already been shipped.');
        Existed := UserSetup.Get(UserId());
        if not Existed then begin
            UserSetup.Init();
            UserSetup."User ID" := CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"));
            UserSetup.Insert();
        end;
        OldPolicy := UserSetup."Service Invoice Posting Policy";
        if MandatoryPolicy then
            UserSetup."Service Invoice Posting Policy" := UserSetup."Service Invoice Posting Policy"::Mandatory
        else
            UserSetup."Service Invoice Posting Policy" := UserSetup."Service Invoice Posting Policy"::Allowed;
        UserSetup.Modify();
        Commit();
        if ExplicitFlags then begin
            ShipFlag := 'true';
            InvoiceFlag := 'true';
        end;
        Preview := PostData.Preview(OrderNo, ShipFlag, '', InvoiceFlag, Lcid);
        Assert.AreEqual(0, PostData.PostedInvoices(OrderNo), 'Preview leaves no invoice.');
        Assert.AreEqual(1, PostData.PostedShipments(OrderNo), 'Preview creates no additional shipment.');
        Response := PostData.Post(OrderNo, ShipFlag, '', InvoiceFlag, 1, Lcid);
        if Existed then begin
            UserSetup."Service Invoice Posting Policy" := OldPolicy;
            UserSetup.Modify();
        end else
            UserSetup.Delete();
        Commit();
        PostData.AssertSuccess(Preview);
        Assert.IsTrue(PostData.BooleanValue(Preview, 'rollback'), 'Preview of already-shipped quantities rolls back.');
        Assert.IsTrue(PostData.IntegerValue(Preview, 'entryCount') > 0, 'Preview captures the remaining invoice entries.');
        PostData.AssertSuccess(Response);
        Assert.AreEqual(1, PostData.ArrayCount(Response, 'postedDocuments'), 'Only the remaining invoice is posted.');
        Assert.AreEqual(1, PostData.PostedShipments(OrderNo), 'The existing shipment is not duplicated.');
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'The shipped quantities are invoiced.');
    end;

}
