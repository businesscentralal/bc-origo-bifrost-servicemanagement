namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 24 native conversion, signing, change status and transaction refusal paths.</summary>
codeunit 97764 "Svc Contract Lifecycle Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Contract Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_QuoteBecomesSignedFiledContract()
    var
        Header: Record "Service Contract Header";
        Filed: Record "Filed Service Contract Header";
        Line: Record "Service Contract Line";
        Response: JsonObject;
    begin
        // Story #24 AC01 | Time: fixed owned dates | Risk: quote conversion loses its filed copy.
        Fixture.Create(Header, true);
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.ContractQuote.MakeContract", Fixture.Request(Header, true), '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText(Response));
        Assert.AreEqual('Signed', Data.TextValue(Response, 'contractStatus'), 'Native conversion already signs.');
        Assert.IsFalse(Header.Get(Header."Contract Type"::Quote, Header."Contract No."), 'Quote removed only on success.');
        Header.Get(Header."Contract Type"::Contract, Header."Contract No.");
        Assert.AreEqual(Header.Status::Signed, Header.Status, 'Contract signed.');
        Assert.AreNotEqual(0D, Header."Next Invoice Date", 'Next invoice date set.');
        Filed.SetRange("Contract Type", Filed."Contract Type"::Quote);
        Filed.SetRange("Contract No.", Header."Contract No.");
        Assert.IsFalse(Filed.IsEmpty(), 'Quote filed.');
        Line.Get(Header."Contract Type", Header."Contract No.", 10000);
        Assert.AreEqual(Header."Customer No.", Line."Customer No.", 'Owned item line moved.');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Sign", Fixture.Request(Header, true), '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText(Response));
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC01_UnsignedContractSignsWithoutInvoice()
    var
        Header: Record "Service Contract Header";
        Invoice: Record "Service Header";
        Response: JsonObject;
    begin
        // Story #24 AC01 | Risk: declining the first invoice still creates one.
        Fixture.Create(Header, false);
        Header."Next Invoice Period Start" := DMY2Date(1, 2, 2026);
        Header.Modify();
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Sign", Fixture.Request(Header, true), '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText(Response));
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(Header.Status::Signed, Header.Status, 'Signed.');
        Assert.AreEqual('', Data.TextValue(Response, 'invoiceNo'), 'No new invoice.');
        Invoice.SetRange("Customer No.", Header."Customer No.");
        Assert.IsTrue(Invoice.IsEmpty(), 'Declined invoice not created.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC01_InvoiceChoiceCreatesUnpostedInvoice()
    var
        Header: Record "Service Contract Header";
        Invoice: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #24 AC01 | Risk: first-period invoice is omitted or posted without permission.
        Fixture.Create(Header, false);
        Header."Next Invoice Period Start" := DMY2Date(1, 2, 2026);
        Header.Modify();
        Request := Fixture.Request(Header, true);
        Request.Replace('createInvoice', true);
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Sign", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText(Response));
        Assert.AreNotEqual('', Data.TextValue(Response, 'invoiceNo'), 'First invoice returned.');
        Assert.IsTrue(Invoice.Get(Invoice."Document Type"::Invoice, Data.TextValue(Response, 'invoiceNo')), 'Invoice remains unposted.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC02_LockUnlockAndRepeatedStates()
    var
        Header: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #24 AC02 | Risk: repeat silently changes state or confirmation is incorrectly needed.
        Fixture.Create(Header, false);
        Request := Fixture.Request(Header, false);
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Unlock", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Lock", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText(Response));
        Assert.AreEqual('Open', Data.TextValue(Response, 'changeStatusBefore'), 'Before.');
        Assert.AreEqual('Locked', Data.TextValue(Response, 'changeStatusAfter'), 'After.');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Lock", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Clear(Request);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Unlock", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText(Response));
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(Header."Change Status"::Open, Header."Change Status", 'Persisted state.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC03_CountConfirmationWritesNothing()
    var
        Header: Record "Service Contract Header";
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
        Pass: Integer;
    begin
        // Story #24 AC03 | Risk: conversion removes a quote without confirming one record.
        for Pass := 1 to 2 do begin
            Fixture.Create(Header, Pass = 1);
            TypeValue := "Message Type ori"::"Service.Contract.Sign";
            if Pass = 1 then
                TypeValue := "Message Type ori"::"Service.ContractQuote.MakeContract";
            Request := Fixture.Request(Header, false);
            Commit();
            Response := InvokeAndCheckLog(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'ConfirmationRequired');
            Request.Add('expectedCount', 2);
            Response := InvokeAndCheckLog(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'ConfirmationMismatch');
            Header.Get(Header."Contract Type", Header."Contract No.");
            Assert.AreEqual(Header.Status::" ", Header.Status, 'Unchanged status.');
            Fixture.Cleanup();
        end;
    end;

    [Test]
    procedure Scenario_AC04_NativeFailureKeepsQuoteAndNoContract()
    var
        Header: Record "Service Contract Header";
        Response: JsonObject;
        Number: Code[20];
    begin
        // Story #24 AC04 | Risk: native validation failure leaves a partial conversion.
        Fixture.Create(Header, true);
        Header."Serv. Contract Acc. Gr. Code" := '';
        Header.Modify();
        Number := Header."Contract No.";
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.ContractQuote.MakeContract", Fixture.Request(Header, true), '', 1033, false);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(Header.Get(Header."Contract Type"::Quote, Number), 'Original quote retained.');
        Assert.IsFalse(Header.Get(Header."Contract Type"::Contract, Number), 'No partial contract.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_DeclinedDateChoiceWritesNothing()
    var
        Header: Record "Service Contract Header";
        Line: Record "Service Contract Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #24 AC04 | Risk: hidden prompts silently accept missing service dates.
        Fixture.Create(Header, false);
        Line.Get(Header."Contract Type", Header."Contract No.", 10000);
        Line."Next Planned Service Date" := 0D;
        Line.Modify();
        Request := Fixture.Request(Header, true);
        Request.Add('acceptMissingServiceDate', false);
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Contract.Sign", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(Header.Status::" ", Header.Status, 'No signature.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_ConversionCollisionRollsBackFiling()
    var
        Header: Record "Service Contract Header";
        Existing: Record "Service Contract Header";
        Filed: Record "Filed Service Contract Header";
        Response: JsonObject;
    begin
        // Story #24 AC04 | Risk: a failure after filing leaves a partial converted document.
        Fixture.Create(Header, true);
        Existing := Header;
        Existing."Contract Type" := Existing."Contract Type"::Contract;
        Existing.Insert();
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.ContractQuote.MakeContract", Fixture.Request(Header, true), '', 1033, false);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(Header.Get(Header."Contract Type"::Quote, Existing."Contract No."), 'Quote retained.');
        Filed.SetRange("Contract No.", Existing."Contract No.");
        Assert.IsTrue(Filed.IsEmpty(), 'Filing before the collision was rolled back.');
        Existing.Get(Existing."Contract Type", Existing."Contract No.");
        Assert.AreEqual(Existing.Status::" ", Existing.Status, 'Existing contract unchanged.');
        Fixture.Cleanup();
    end;

    local procedure ResponseText(Response: JsonObject): Text
    var
        Result: Text;
    begin
        Response.WriteTo(Result);
        exit(Result);
    end;
    local procedure InvokeAndCheckLog(MessageType: Enum "Message Type ori"; Request: JsonObject; Subject: Text; LanguageId: Integer; OmitCommit: Boolean): JsonObject
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
        Assert.IsFalse(OmitCommit, 'Contract tests exercise the persisted public dispatcher.');
        Request.WriteTo(RequestText);
        Input.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250),
            'Owned service contract test #24', 'text/json', Input, TaskId, LanguageId, MessageId, Output, ContentType, ResponseTime);
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
