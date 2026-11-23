namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 25 confirmation, strict requests, bounds and persisted refusal logs.</summary>
codeunit 97786 "Svc Contr Job Validate Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Contr Job Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC04_MissingAndWrongCountsWriteNothing()
    var
        Header: Record "Service Contract Header";
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // AC04: every operation reports the selected contract count and exact list before writes.
        foreach TypeValue in Fixture.Types() do begin
            Fixture.Create(Header);
            Request := Fixture.Request(TypeValue, Header);
            Request.Remove('expectedCount');
            Commit();
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'ConfirmationRequired');
            Response.Get('count', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Contract count.');
            Response.Get('contractNos', Token);
            Assert.AreEqual(1, Token.AsArray().Count(), 'Selected list.');
            Request.Add('expectedCount', 2);
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'ConfirmationMismatch');
            AssertUnchanged(Header);
            Fixture.Cleanup();
        end;
    end;

    [Test]
    procedure Scenario_AC05_UnknownKeyUnsignedAndUnknownContract()
    var
        Header: Record "Service Contract Header";
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // AC05: strict keys and all selected contract states are checked without documents.
        foreach TypeValue in Fixture.Types() do begin
            Fixture.Create(Header);
            Request := Fixture.Request(TypeValue, Header);
            Request.Add('unknownKey', true);
            Commit();
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'UnknownParameter');
            Request.Remove('unknownKey');
            Header.Status := Header.Status::" ";
            Header.Modify();
            Commit();
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'PreconditionFailed');
            AssertUnchanged(Header);
            Header.Delete(false);
            Commit();
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'RecordNotFound');
            Fixture.Cleanup();
        end;
    end;

    [Test]
    procedure Scenario_AC05_EmptyScopeAndStrictFormats()
    var
        Header: Record "Service Contract Header";
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
        Numbers: JsonArray;
        DateKey: Text;
    begin
        // AC05: arrays, counts and ISO dates cannot be coerced from strings or invalid values.
        foreach TypeValue in Fixture.Types() do begin
            Fixture.Create(Header);
            Request := Fixture.Request(TypeValue, Header);
            if TypeValue = TypeValue::"Service.Contract.CreateCreditMemo" then
                Request.Remove('contractNo')
            else
                Request.Replace('contractNos', Numbers);
            Commit();
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'MissingParameter');
            Request := Fixture.Request(TypeValue, Header);
            Request.Replace('expectedCount', '1');
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Request := Fixture.Request(TypeValue, Header);
            case TypeValue of
                TypeValue::"Service.Contract.CreateInvoices":
                    DateKey := 'postingDate';
                TypeValue::"Service.Contract.CreateServiceOrders":
                    DateKey := 'startingDate';
                TypeValue::"Service.Contract.CreateCreditMemo":
                    DateKey := 'creditMemoDateTo';
            end;
            Request.Replace(DateKey, '31/01/2026');
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Request.Replace(DateKey, true);
            Response := InvokeAndCheckLog(TypeValue, Request, '');
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            AssertUnchanged(Header);
            Fixture.Cleanup();
        end;
    end;

    [Test]
    procedure Scenario_AC05_OneYearBoundaryAndConflictingScopes()
    var
        Header: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // AC05: inclusive one-year range is valid; its anniversary is outside the bound.
        Fixture.Create(Header);
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateServiceOrders", Header);
        Request.Remove('expectedCount');
        Request.Replace('endingDate', '2026-12-31');
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateServiceOrders", Request, '');
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Request.Replace('endingDate', '2027-01-01');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateServiceOrders", Request, '');
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Request.Replace('endingDate', '2025-12-31');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateServiceOrders", Request, '');
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header);
        Request.Add('customerNo', Header."Customer No.");
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateInvoices", Request, '');
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateCreditMemo", Header);
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateCreditMemo", Request, 'XDIFFERENT');
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        Request.Add('systemId', Format(CreateGuid(), 0, 4));
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateCreditMemo", Request, '');
        Data.AssertRefusal(Response, 'RecordNotFound');
        AssertUnchanged(Header);
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_DuplicateContractCountsOnce()
    var
        Header: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
        Numbers: JsonArray;
        Token: JsonToken;
    begin
        // AC04 edge: repeated identifiers cannot inflate the confirmed count or repeat writes.
        Fixture.Create(Header);
        Numbers.Add(Header."Contract No.");
        Numbers.Add(LowerCase(Header."Contract No."));
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header);
        Request.Replace('contractNos', Numbers);
        Request.Remove('expectedCount');
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateInvoices", Request, '');
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Response.Get('count', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Distinct contract count.');
        AssertUnchanged(Header);
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC05_ContractCountBoundary()
    var
        Header: Record "Service Contract Header";
        Extra: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
        Numbers: JsonArray;
        Token: JsonToken;
        Index: Integer;
    begin
        // AC05: exactly 200 contracts can be reviewed; 201 is refused for lists and filters.
        Fixture.Create(Header);
        Numbers.Add(Header."Contract No.");
        for Index := 2 to 201 do begin
            Extra := Header;
            Extra."Contract No." := CopyStr('X25BOUND' + Format(Index, 0, 9), 1, 20);
            Extra.Insert(false);
            if Index <= 200 then
                Numbers.Add(Extra."Contract No.");
        end;
        Request := Fixture.Request("Message Type ori"::"Service.Contract.CreateInvoices", Header);
        Request.Replace('contractNos', Numbers);
        Request.Remove('expectedCount');
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateInvoices", Request, '');
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Response.Get('count', Token);
        Assert.AreEqual(200, Token.AsValue().AsInteger(), 'Exact upper boundary.');
        Numbers.Add(Extra."Contract No.");
        Request.Replace('contractNos', Numbers);
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateInvoices", Request, '');
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Request.Remove('contractNos');
        Request.Add('customerNo', Header."Customer No.");
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.CreateInvoices", Request, '');
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Extra.SetRange("Customer No.", Header."Customer No.");
        Extra.SetFilter("Contract No.", 'X25BOUND*');
        Extra.DeleteAll(false);
        Fixture.Cleanup();
    end;

    local procedure AssertUnchanged(Header: Record "Service Contract Header")
    var
        Document: Record "Service Header";
    begin
        Document.SetRange("Customer No.", Header."Customer No.");
        Assert.IsTrue(Document.IsEmpty(), 'Refused operations created no documents.');
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(DMY2Date(1, 1, 2026), Header."Next Invoice Date", 'Invoice date unchanged.');
    end;

    local procedure InvokeAndCheckLog(MessageType: Enum "Message Type ori"; Request: JsonObject; Subject: Text): JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        RequestText: Text;
        LoggedResponseText: Text;
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
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250),
            'Owned service contract test #25', 'text/json', Input, TaskId, 1033, MessageId, Output, ContentType, ResponseTime);
        Assert.IsFalse(IsNullGuid(MessageId), 'Foundation returned the persisted message id.');
        Output.GetSubText(LoggedResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(LoggedResponseText), 'Persisted response must be JSON.');
        if Data.TextValue(Response, 'status') = 'Error' then begin
            // Use Foundation's product API so the assertion also runs without Foundation Tests installed.
            LogRequest.Add('tableName', 'Message ori');
            LogRequest.Add('tableView', 'WHERE(Id=CONST(' + Format(MessageId, 0, 4) + '))');
            LogResponse := Data.Invoke("Message Type ori"::"Data.Records.Get", LogRequest, '', 1033, true);
            Assert.AreEqual('Success', Data.TextValue(LogResponse, 'status'), 'Read back persisted error message.');
            LogResponse.Get('noOfRecords', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Foundation retained this exact error message.');
        end;
        exit(Response);
    end;

}
