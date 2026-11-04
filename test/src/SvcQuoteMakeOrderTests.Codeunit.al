namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Setup;
using Origo.Bifrost;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Exercises quote conversion, persisted results, refusals and native rollback through the public dispatcher.</summary>
codeunit 97719 "Svc Quote MakeOrder Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_No_ConvertsAllLines()
    begin
        ConvertAndAssert('no', 1033, false);
    end;

    [Test]
    procedure Scenario_AC02_SystemId_ConvertsQuote()
    begin
        ConvertAndAssert('systemId', 1033, false);
    end;

    [Test]
    procedure Scenario_AC02_Subject_ConvertsQuote()
    begin
        ConvertAndAssert('subject', 1033, false);
    end;

    [Test]
    procedure Scenario_AC10_OmitCommit_StillCommits()
    begin
        ConvertAndAssert('no', 1033, true);
    end;

    [Test]
    procedure Scenario_AC10_CallerRollback_OrderPersists()
    var
        Quote: Record "Service Header";
        OrderHeader: Record "Service Header";
        Caller: Codeunit "Svc Quote Caller Rollback ori";
        QuoteNo: Code[20];
    begin
        Data.CreateDocument(Quote, Quote."Document Type"::Quote);
        QuoteNo := Quote."No.";
        Commit();
        asserterror Caller.Run(Quote);
        Assert.ExpectedError('X-EXPECTED-CALLER-ROLLBACK');
        Assert.IsFalse(Quote.Get(Quote."Document Type"::Quote, QuoteNo), 'Committed conversion removed the quote.');
        OrderHeader.SetRange("Document Type", OrderHeader."Document Type"::Order);
        OrderHeader.SetRange("Quote No.", QuoteNo);
        Assert.IsTrue(OrderHeader.FindFirst(), 'The converted order survives the later caller rollback.');
        Assert.AreNotEqual('X-CALLER-ROLLBACK', OrderHeader.Description, 'The unrelated caller write rolls back.');
    end;

    [Test]
    procedure Scenario_AC14_Icelandic_ConvertsQuote()
    begin
        ConvertAndAssert('no', 1039, false);
    end;

    [Test]
    procedure Scenario_AC04_ActiveAllocation_NeedsReallocation()
    var
        Header: Record "Service Header";
        OrderHeader: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Allocation: Record "Service Order Allocation";
        Resource: Record Resource;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Data.CreateResourceFor(Header."Customer No.", Resource);
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        Allocation.LockTable();
        if Allocation.FindLast() then
            Allocation."Entry No." += 1
        else
            Allocation."Entry No." := 1;
        Allocation."Document Type" := Header."Document Type";
        Allocation."Document No." := Header."No.";
        Allocation."Service Item Line No." := ItemLine."Line No.";
        Allocation."Resource No." := Resource."No.";
        Allocation."Allocation Date" := WorkDate();
        Allocation."Allocated Hours" := 2;
        Allocation.Status := Allocation.Status::Active;
        Allocation.Insert(true);
        Commit();
        Response := Convert(Header, 1);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Native conversion.');
        OrderHeader.Get(OrderHeader."Document Type"::Order, Data.TextValue(Response, 'orderNo'));
        Allocation.Reset();
        Allocation.SetRange("Document Type", OrderHeader."Document Type");
        Allocation.SetRange("Document No.", OrderHeader."No.");
        Allocation.FindFirst();
        Assert.AreEqual(Allocation.Status::"Reallocation Needed", Allocation.Status, 'BC marks the allocation for reallocation.');
        Response.Get('allocationsToReallocate', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Response count matches the order.');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Service.Allocation.Allocate'), 'Next step names allocation.');
    end;

    [Test]
    procedure Scenario_AC05_MissingCustomer_Refused()
    begin
        MissingParty(false);
    end;

    [Test]
    procedure Scenario_AC05_MissingBillTo_Refused()
    begin
        MissingParty(true);
    end;

    [Test]
    procedure Scenario_AC06_BlockedCustomer_RollsBack()
    var
        Header: Record "Service Header";
        Customer: Record Customer;
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Customer.Get(Header."Customer No.");
        Customer.Blocked := Customer.Blocked::All;
        Customer.Modify();
        Commit();
        Response := Convert(Header, 1);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        AssertUnchanged(Header);
    end;

    [Test]
    procedure Scenario_AC06_BlockedServiceItem_RollsBack()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        ServiceItem: Record "Service Item";
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        ServiceItem.Get(ItemLine."Service Item No.");
        ServiceItem.Blocked := ServiceItem.Blocked::All;
        ServiceItem.Modify();
        Commit();
        Response := Convert(Header, 1);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        AssertUnchanged(Header);
    end;

    [Test]
    procedure Scenario_AC06_ServiceBlockedItem_RollsBack()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Item: Record Item;
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.SetRange(Type, Line.Type::Item);
        Line.FindFirst();
        Item.Get(Line."No.");
        Item."Service Blocked" := true;
        Item.Modify();
        Commit();
        Response := Convert(Header, 1);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        AssertUnchanged(Header);
    end;

    [Test]
    procedure Scenario_AC07_NoOrderSeries_Refused()
    var
        Header: Record "Service Header";
        Setup: Record "Service Mgt. Setup";
        PriorSeries: Code[20];
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Setup.Get();
        PriorSeries := Setup."Service Order Nos.";
        Setup."Service Order Nos." := '';
        Setup.Modify();
        Commit();
        Response := Convert(Header, 1);
        Setup.Get();
        Setup."Service Order Nos." := PriorSeries;
        Setup.Modify();
        Commit();
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Service Order Nos.'), 'Setup recovery names the field.');
        AssertUnchanged(Header);
    end;

    [Test]
    procedure Scenario_AC08_OrderSystemId_Refused()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateHeader(Header, Header."Document Type"::Order);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('systemId', Data.TextValue(Response, 'parameter'), 'Wrong type identifier.');
        Assert.AreEqual('Quote', Data.TextValue(Response, 'expected'), 'Required scope.');
    end;

    [Test]
    procedure Scenario_AC08_UnknownNumber_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('no', 'X-NOT-FOUND');
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC09_MissingIdentifier_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'MissingParameter');
    end;

    [Test]
    procedure Scenario_AC09_MalformedGuid_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('systemId', 'not-a-guid');
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
    end;

    [Test]
    procedure Scenario_AC09_MultipleErrors_Collected()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('no', '');
        Request.Add('systemId', 'not-a-guid');
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'MultipleErrors');
    end;

    [Test]
    procedure Scenario_AC09_UnknownParameter_DispatcherRefuses()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Request.Add('no', Header."No.");
        Request.Add('extra', 'x');
        Commit();
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'UnknownParameter');
        Assert.AreEqual('extra', Data.TextValue(Response, 'parameter'), 'Strict dispatcher names the key.');
        AssertUnchanged(Header);
    end;

    [Test]
    procedure Scenario_ConflictingIdentifiers_Refused()
    var
        First: Record "Service Header";
        Second: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(First, First."Document Type"::Quote);
        Data.CreateDocument(Second, Second."Document Type"::Quote);
        Request.Add('no', First."No.");
        Request.Add('systemId', Format(Second.SystemId, 0, 4));
        Commit();
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        AssertUnchanged(First);
        AssertUnchanged(Second);
    end;

    local procedure ConvertAndAssert(KeyName: Text; LanguageId: Integer; OmitCommit: Boolean)
    var
        Header: Record "Service Header";
        OrderHeader: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Line: Record "Service Line";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Subject: Text;
        QuoteNo: Code[20];
        QuoteId: Guid;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        QuoteNo := Header."No.";
        QuoteId := Header.SystemId;
        case KeyName of
            'no': Request.Add('no', QuoteNo);
            'systemId': Request.Add('systemId', Format(QuoteId, 0, 4));
            'subject': Subject := QuoteNo;
        end;
        Request.Add('expectedCount', 1);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Quote.MakeOrder", Request, Subject, LanguageId, OmitCommit);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Conversion succeeds.');
        Assert.AreEqual(QuoteNo, Data.TextValue(Response, 'quoteNo'), 'Original quote.');
        OrderHeader.Get(OrderHeader."Document Type"::Order, Data.TextValue(Response, 'orderNo'));
        Assert.AreEqual(Format(OrderHeader.SystemId, 0, 4), Data.TextValue(Response, 'orderSystemId'), 'Created order identity.');
        Assert.AreEqual(Header."Customer No.", OrderHeader."Customer No.", 'Customer retained.');
        Assert.AreEqual(Header."Customer No.", Data.TextValue(Response, 'customerNo'), 'Response customer.');
        Assert.AreEqual(OrderHeader.Name, Data.TextValue(Response, 'customerName'), 'Response name.');
        Assert.AreEqual(QuoteNo, OrderHeader."Quote No.", 'BC trace to source quote.');
        Assert.IsFalse(Header.GetBySystemId(QuoteId), 'Source quote is deleted.');
        ItemLine.SetRange("Document Type", OrderHeader."Document Type");
        ItemLine.SetRange("Document No.", OrderHeader."No.");
        Response.Get('serviceItemLines', Token);
        Assert.AreEqual(1, ItemLine.Count(), 'Service item line transferred.');
        Assert.AreEqual(ItemLine.Count(), Token.AsValue().AsInteger(), 'Response count.');
        Line.SetRange("Document Type", OrderHeader."Document Type");
        Line.SetRange("Document No.", OrderHeader."No.");
        Response.Get('serviceLines', Token);
        Assert.AreEqual(2, Line.Count(), 'Item and Resource lines transferred.');
        Assert.AreEqual(Line.Count(), Token.AsValue().AsInteger(), 'Response line count.');
        Clear(Request);
        Request.Add('no', QuoteNo);
        Response := Invoke(Request);
        Data.AssertRefusal(Response, 'RecordNotFound');
    end;

    local procedure MissingParty(BillTo: Boolean)
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        if BillTo then
            Header."Bill-to Customer No." := ''
        else
            Header."Customer No." := '';
        Header.Modify();
        Commit();
        Response := Convert(Header, 1);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        AssertUnchanged(Header);
    end;

    local procedure AssertUnchanged(Header: Record "Service Header")
    var
        OrderHeader: Record "Service Header";
    begin
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'Quote remains.');
        OrderHeader.SetRange("Document Type", OrderHeader."Document Type"::Order);
        OrderHeader.SetRange("Quote No.", Header."No.");
        Assert.IsTrue(OrderHeader.IsEmpty(), 'No partial order remains.');
    end;

    local procedure Convert(Header: Record "Service Header"; Count: Integer): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('no', Header."No.");
        Request.Add('expectedCount', Count);
        exit(Invoke(Request));
    end;

    local procedure Invoke(Request: JsonObject): JsonObject
    begin
        exit(Data.Invoke("Message Type ori"::"Service.Quote.MakeOrder", Request, '', 1033, false));
    end;
    [Test]
    procedure Scenario_AC12_QuoteGenericWrite_RemainsAllowed()
    var
        Header: Record "Service Header";
        ChangeLog: Record "Change Log Setup";
        ChangeLogTable: Record "Change Log Setup (Table)";
        PriorLog: Record "Change Log Setup";
        PriorTable: Record "Change Log Setup (Table)";
        HadLog: Boolean;
        HadTable: Boolean;
        Request: JsonObject;
        Response: JsonObject;
        Serialized: Text;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Commit();
        // Exercise the ordinary field under a legitimate Change Log write-guard configuration.
        // No Foundation setup table is read or written, and dedicated restrictions remain active.
        HadLog := ChangeLog.Get();
        PriorLog := ChangeLog;
        if not HadLog then begin
            ChangeLog.Init();
            ChangeLog.Insert();
        end;
        ChangeLog."Change Log Activated" := true;
        ChangeLog.Modify();
        HadTable := ChangeLogTable.Get(Database::"Service Header");
        PriorTable := ChangeLogTable;
        if not HadTable then begin
            ChangeLogTable.Init();
            ChangeLogTable."Table No." := Database::"Service Header";
            ChangeLogTable.Insert();
        end;
        ChangeLogTable."Log Modification" := ChangeLogTable."Log Modification"::"All Fields";
        ChangeLogTable.Modify();
        Commit();
        Response := SetField(Header.SystemId, 'Description', 'X-service lifecycle test');
        if HadTable then begin
            ChangeLogTable := PriorTable;
            ChangeLogTable.Modify();
        end else
            ChangeLogTable.Delete();
        if HadLog then begin
            ChangeLog := PriorLog;
            ChangeLog.Modify();
        end else
            ChangeLog.Delete();
        Commit();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Ordinary edit allowed.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual('X-service lifecycle test', Header.Description, 'Description persisted.');
        Request.Add('tableName', 'Service Header');
        Request.Add('tableView', 'WHERE(No.=CONST(' + Header."No." + '))');
        Response := Data.Invoke("Message Type ori"::"Data.Records.Get", Request, '', 1033, false);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains(Header."No."), 'Ordinary read remains allowed.');
    end;

    local procedure SetField(Id: Guid; FieldName: Text; Value: Text): JsonObject
    var
        Request: JsonObject;
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
    begin
        Fields.Add(FieldName, Value);
        Entry.Add('id', Format(Id, 0, 4));
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Request.Add('tableName', 'Service Header');
        Request.Add('data', Entries);
        exit(Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', 1033, false));
    end;
}
