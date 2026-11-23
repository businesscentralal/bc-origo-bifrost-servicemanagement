namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Loaner;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves loaner lending, receipt, validation and unchanged state through the public dispatcher.</summary>
codeunit 97762 "Svc Loaner Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Loaner Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC01_LendAndReceive_1033()
    begin
        RoundTrip(1033);
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC01_LendAndReceive_1039()
    begin
        RoundTrip(1039);
        Fixture.Cleanup();
    end;

    local procedure RoundTrip(LanguageId: Integer)
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Entry: Record "Loaner Entry";
        Response: JsonObject;
        Raw: Text;
    begin
        Fixture.Create(Line, Loaner);
        Commit();
        Response := Fixture.Lend(Line, Loaner."No.", LanguageId);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Loaner.CalcFields(Lent);
        Assert.IsTrue(Loaner.Lent, 'Lend must create an open loan, not just change the field.');
        Entry.SetRange("Loaner No.", Loaner."No.");
        Entry.SetRange(Lent, true);
        Assert.AreEqual(1, Entry.Count(), 'Exactly one open loan history entry.');
        Response := Data.Invoke("Message Type ori"::"Service.Loaner.Receive", Fixture.Request(Line), '', LanguageId, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Loaner.CalcFields(Lent);
        Assert.IsFalse(Loaner.Lent, 'The received loaner is available.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual('', Line."Loaner No.", 'The order line is cleared.');
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC02_PostedShipment_ClosesLoan()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        ShipmentLine: Record "Service Shipment Item Line";
        Request: JsonObject;
    begin
        LendFixture(Line, Loaner);
        Fixture.Shipment(Line, ShipmentLine);
        Request.Add('postedShipmentNo', ShipmentLine."No.");
        Request.Add('lineNo', ShipmentLine."Line No.");
        Commit();
        AssertSuccess(Send(Request, 1033));
        ShipmentLine.Get(ShipmentLine."No.", ShipmentLine."Line No.");
        Assert.AreEqual('', ShipmentLine."Loaner No.", 'Shipment line cleared.');
        AssertClosed(Line, Loaner);
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC02_LoanerNumber_ClosesLoan()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Request: JsonObject;
    begin
        LendFixture(Line, Loaner);
        Request.Add('loanerNo', Loaner."No.");
        AssertSuccess(Send(Request, 1033));
        AssertClosed(Line, Loaner);
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC02_LoanerNumber_AfterOrderRemoved()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        ShipmentLine: Record "Service Shipment Item Line";
        Request: JsonObject;
    begin
        LendFixture(Line, Loaner);
        Fixture.Shipment(Line, ShipmentLine);
        Line.Delete();
        Commit();
        Request.Add('loanerNo', Loaner."No.");
        AssertSuccess(Send(Request, 1033));
        Loaner.CalcFields(Lent);
        Assert.IsFalse(Loaner.Lent, 'Native receipt finds the shipment after the order line is gone.');
        ShipmentLine.Get(ShipmentLine."No.", ShipmentLine."Line No.");
        Assert.AreEqual('', ShipmentLine."Loaner No.", 'Shipment line cleared.');
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC02_LoanerNumber_OrphanHistory()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Request: JsonObject;
    begin
        LendFixture(Line, Loaner);
        Line.Delete();
        Commit();
        Request.Add('loanerNo', Loaner."No.");
        AssertSuccess(Send(Request, 1033));
        Loaner.CalcFields(Lent);
        Assert.IsFalse(Loaner.Lent, 'Native receive-anyway closes a loan with no remaining line.');
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC03_AgreeingIdentifiers_ReceiveOnce()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        ShipmentLine: Record "Service Shipment Item Line";
        Request: JsonObject;
    begin
        LendFixture(Line, Loaner);
        Fixture.Shipment(Line, ShipmentLine);
        Commit();
        Request := Fixture.Request(Line);
        Request.Add('postedShipmentNo', ShipmentLine."No.");
        Request.Add('lineNo', ShipmentLine."Line No.");
        Request.Add('loanerNo', Loaner."No.");
        AssertSuccess(Send(Request, 1033));
        AssertClosed(Line, Loaner);
        Data.AssertRefusal(Send(Request, 1033), 'PreconditionFailed');
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC03_ConflictingLoans_NothingChanges()
    var
        Line: Record "Service Item Line";
        OtherLine: Record "Service Item Line";
        Loaner: Record Loaner;
        OtherLoaner: Record Loaner;
        ShipmentLine: Record "Service Shipment Item Line";
        Request: JsonObject;
    begin
        LendFixture(Line, Loaner);
        LendFixture(OtherLine, OtherLoaner);
        Request := Fixture.Request(Line);
        Request.Add('loanerNo', OtherLoaner."No.");
        Data.AssertRefusal(Send(Request, 1033), 'ConflictingIdentifiers');
        Fixture.Shipment(OtherLine, ShipmentLine);
        Commit();
        Request := Fixture.Request(Line);
        Request.Add('postedShipmentNo', ShipmentLine."No.");
        Request.Add('lineNo', ShipmentLine."Line No.");
        Data.AssertRefusal(Send(Request, 1039), 'ConflictingIdentifiers');
        AssertOpen(Line, Loaner);
        AssertOpen(OtherLine, OtherLoaner);
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC03_InputErrors_NothingChanges()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Request: JsonObject;
        Invalid: Text;
    begin
        LendFixture(Line, Loaner);
        Data.AssertRefusal(Send(Request, 1033), 'MissingParameter');
        Request.Add('documentNo', Line."Document No.");
        Data.AssertRefusal(Send(Request, 1033), 'MissingParameter');
        foreach Invalid in '1.5|"10000"|0|-1|2147483648|null|true|{}|[]'.Split('|') do begin
            Request.ReadFrom('{"documentNo":"' + Line."Document No." + '","serviceItemLineNo":' + Invalid + '}');
            Data.AssertRefusal(Send(Request, 1033), 'InvalidParameterFormat');
        end;
        Request := Fixture.Request(Line);
        Request.Add('unexpected', true);
        Data.AssertRefusal(Send(Request, 1033), 'UnknownParameter');
        Clear(Request);
        Request.Add('loanerNo', 'X-MISSING');
        Data.AssertRefusal(Send(Request, 1033), 'RecordNotFound');
        Request := Fixture.Request(Line);
        Request.Replace('documentNo', 'X-MISSING');
        Data.AssertRefusal(Send(Request, 1033), 'RecordNotFound');
        Request := Fixture.Request(Line);
        Request.Replace('serviceItemLineNo', 2147483647);
        Data.AssertRefusal(Send(Request, 1033), 'RecordNotFound');
        Clear(Request);
        Request.Add('loanerNo', 'X123456789012345678901');
        Data.AssertRefusal(Send(Request, 1033), 'InvalidParameterFormat');
        Clear(Request);
        Request.Add('loanerNo', '');
        Data.AssertRefusal(Send(Request, 1033), 'InvalidParameterFormat');
        AssertOpen(Line, Loaner);
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC03_NotLent_TranslatedRefusals()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        Fixture.Create(Line, Loaner);
        Request.Add('loanerNo', Loaner."No.");
        Commit();
        English := Send(Request, 1033);
        Icelandic := Send(Request, 1039);
        Data.AssertRefusal(English, 'PreconditionFailed');
        Data.AssertRefusal(Icelandic, 'PreconditionFailed');
        Assert.AreNotEqual(Data.TextValue(English, 'error'), Data.TextValue(Icelandic, 'error'), 'Refusal translated.');
        Assert.AreNotEqual(Data.TextValue(English, 'nextStep'), Data.TextValue(Icelandic, 'nextStep'), 'Recovery translated.');
        Loaner.CalcFields(Lent);
        Assert.IsFalse(Loaner.Lent, 'Still available.');
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC03_LendingRefusals_NothingChanges()
    var
        Line: Record "Service Item Line";
        OtherLine: Record "Service Item Line";
        Loaner: Record Loaner;
        OtherLoaner: Record Loaner;
        Response: JsonObject;
        Request: JsonObject;
    begin
        Fixture.Create(Line, Loaner);
        Loaner.Blocked := true;
        Loaner.Modify();
        Commit();
        Data.AssertRefusal(Fixture.Lend(Line, Loaner."No.", 1033), 'PreconditionFailed');
        Loaner.Blocked := false;
        Loaner.Modify();
        Commit();
        AssertSuccess(Fixture.Lend(Line, Loaner."No.", 1033));
        Fixture.Create(OtherLine, OtherLoaner);
        Commit();
        Data.AssertRefusal(Fixture.Lend(OtherLine, Loaner."No.", 1039), 'PreconditionFailed');
        Data.AssertRefusal(Fixture.Lend(OtherLine, 'X-MISSING', 1033), 'RecordNotFound');
        Request := Fixture.Request(Line);
        Request.Add('systemId', Format(OtherLine.SystemId, 0, 4));
        Request.Add('loanerNo', OtherLoaner."No.");
        Response := Data.Invoke("Message Type ori"::"Service.Loaner.Lend", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        AssertOpen(Line, Loaner);
        OtherLine.Get(OtherLine."Document Type", OtherLine."Document No.", OtherLine."Line No.");
        Assert.AreEqual('', OtherLine."Loaner No.", 'Refused lending leaves the other line empty.');
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC03_LendBySystemId_AndGenericWriteRefused()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Request: JsonObject;
        Response: JsonObject;
        Raw: Text;
    begin
        Fixture.Create(Line, Loaner);
        Commit();
        Response := Fixture.GenericLend(Line, Loaner."No.", 1033);
        Data.AssertRefusal(Response, 'PermissionDenied');
        Response.WriteTo(Raw);
        Assert.IsTrue(Raw.Contains('Service.Loaner.Lend'), 'Dedicated-path hint.');
        Request.Add('systemId', Format(Line.SystemId, 0, 4));
        Request.Add('loanerNo', Loaner."No.");
        AssertSuccess(Data.Invoke("Message Type ori"::"Service.Loaner.Lend", Request, '', 1033, false));
        AssertOpen(Line, Loaner);
        Data.AssertRefusal(Fixture.GenericLend(Line, '', 1039), 'PermissionDenied');
        AssertOpen(Line, Loaner);
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC03_LendInputErrors_AreLogged()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Request: JsonObject;
        Invalid: Text;
    begin
        Fixture.Create(Line, Loaner);
        Commit();
        Data.AssertRefusal(SendType("Message Type ori"::"Service.Loaner.Lend", Request, 1033), 'MissingParameter');
        Request := Fixture.Request(Line);
        Data.AssertRefusal(SendType("Message Type ori"::"Service.Loaner.Lend", Request, 1033), 'MissingParameter');
        Request.Add('loanerNo', Loaner."No.");
        Request.Add('unknown', true);
        Data.AssertRefusal(SendType("Message Type ori"::"Service.Loaner.Lend", Request, 1033), 'UnknownParameter');
        foreach Invalid in '1.5|"10000"|0|-1|2147483648|null|true|{}|[]'.Split('|') do begin
            Request.ReadFrom('{"documentNo":"' + Line."Document No." + '","loanerNo":"' + Loaner."No." + '","serviceItemLineNo":' + Invalid + '}');
            Data.AssertRefusal(SendType("Message Type ori"::"Service.Loaner.Lend", Request, 1033), 'InvalidParameterFormat');
        end;
        Request := Fixture.Request(Line);
        Request.Add('loanerNo', Loaner."No.");
        Request.Replace('documentNo', 'X-MISSING');
        Data.AssertRefusal(SendType("Message Type ori"::"Service.Loaner.Lend", Request, 1033), 'RecordNotFound');
        Request := Fixture.Request(Line);
        Request.Add('loanerNo', Loaner."No.");
        Request.Add('systemId', 'not-a-guid');
        Data.AssertRefusal(SendType("Message Type ori"::"Service.Loaner.Lend", Request, 1039), 'InvalidParameterFormat');
        Loaner.CalcFields(Lent);
        Assert.IsFalse(Loaner.Lent, 'Invalid requests did not create a loan.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual('', Line."Loaner No.", 'Invalid requests did not change the line.');
        Fixture.Cleanup();
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC03_NativeError_RollsBack()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Failure: Codeunit "Svc Loaner Failure Tst ori";
        BeforeDescription: Text;
    begin
        LendFixture(Line, Loaner);
        BeforeDescription := Line.Description;
        BindSubscription(Failure);
        Data.AssertRefusal(Send(Fixture.Request(Line), 1033), 'BusinessCentralError');
        UnbindSubscription(Failure);
        AssertOpen(Line, Loaner);
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(BeforeDescription, Line.Description, 'Native failed write rolled back.');
        Fixture.Cleanup();
    end;

    local procedure LendFixture(var Line: Record "Service Item Line"; var Loaner: Record Loaner)
    begin
        Fixture.Create(Line, Loaner);
        Commit();
        AssertSuccess(Fixture.Lend(Line, Loaner."No.", 1033));
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
    end;

    local procedure AssertOpen(Line: Record "Service Item Line"; Loaner: Record Loaner)
    begin
        Loaner.CalcFields(Lent);
        Assert.IsTrue(Loaner.Lent, 'Refusal retains the open loan.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(Loaner."No.", Line."Loaner No.", 'Refusal retains the line.');
    end;

    local procedure AssertClosed(Line: Record "Service Item Line"; Loaner: Record Loaner)
    var
        Entry: Record "Loaner Entry";
    begin
        Loaner.CalcFields(Lent);
        Assert.IsFalse(Loaner.Lent, 'Loaner available.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual('', Line."Loaner No.", 'Line cleared.');
        Entry.SetRange("Loaner No.", Loaner."No.");
        Assert.AreEqual(1, Entry.Count(), 'History retained.');
        Entry.FindFirst();
        Assert.IsFalse(Entry.Lent, 'Loan closed.');
        Assert.AreEqual(WorkDate(), Entry."Date Received", 'Receipt date recorded.');
        Assert.AreNotEqual(0T, Entry."Time Received", 'Receipt time recorded.');
    end;

    local procedure AssertSuccess(Response: JsonObject)
    var
        Raw: Text;
    begin
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
    end;

    local procedure Send(Request: JsonObject; LanguageId: Integer): JsonObject
    begin
        exit(SendType("Message Type ori"::"Service.Loaner.Receive", Request, LanguageId));
    end;

    local procedure SendType(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer): JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        Response: JsonObject;
        LogRequest: JsonObject;
        LogResponse: JsonObject;
        Token: JsonToken;
    begin
        Request.WriteTo(RequestText);
        Input.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '',
            'Owned loaner test #26', 'text/json', Input, TaskId, LanguageId, MessageId, Output, ContentType, ResponseTime);
        Output.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Persisted response is JSON.');
        if Data.TextValue(Response, 'status') = 'Error' then begin
            LogRequest.Add('tableName', 'Message ori');
            LogRequest.Add('tableView', 'WHERE(Id=CONST(' + Format(MessageId, 0, 4) + '))');
            LogResponse := Data.Invoke("Message Type ori"::"Data.Records.Get", LogRequest, '', 1033, true);
            AssertSuccess(LogResponse);
            LogResponse.Get('noOfRecords', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Foundation retained the exact error message.');
        end;
        exit(Response);
    end;
    /// <summary>Answers the native loaner confirmation in the interactive AL test runner.</summary>
    [ConfirmHandler]
    procedure ConfirmLoaner(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.IsTrue(LowerCase(Question).Contains('loaner') or LowerCase(Question).Contains('lánst') or LowerCase(Question).Contains('lánsbúnað'), Question);
        Reply := true;
    end;
}
