namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 24 malformed requests and generic-write restrictions.</summary>
codeunit 97765 "Svc Contract Validate Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Contract Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC04_MissingUnknownAndMalformedIdentifiers()
    var
        Types: List of [Enum "Message Type ori"];
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
        KeyName: Text;
    begin
        // Story #24 AC04 | Risk: default or truncated identifiers select unrelated contracts.
        Types.Add("Message Type ori"::"Service.ContractQuote.MakeContract");
        Types.Add("Message Type ori"::"Service.Contract.Sign");
        Types.Add("Message Type ori"::"Service.Contract.Lock");
        Types.Add("Message Type ori"::"Service.Contract.Unlock");
        foreach TypeValue in Types do begin
            Clear(Request);
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'MissingParameter');
            KeyName := 'contractNo';
            if TypeValue = "Message Type ori"::"Service.ContractQuote.MakeContract" then
                KeyName := 'contractQuoteNo';
            Request.Add(KeyName, 'X-NOT-FOUND-24');
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'RecordNotFound');
            Request.Replace(KeyName, 'X12345678901234567890');
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Clear(Request);
            Request.Add('systemId', 'not-a-guid');
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Clear(Request);
            Request.Add('unexpectedContractKey', true);
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'UnknownParameter');
        end;
    end;

    [Test]
    procedure Scenario_AC04_ConflictingIdentifiersAndSubject()
    var
        Header: Record "Service Contract Header";
        Other: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #24 AC04 | Risk: a matching number hides a conflicting system identifier.
        Fixture.Create(Header, false);
        Fixture.Create(Other, false);
        Request := Fixture.Request(Header, false);
        Request.Add('systemId', Format(Other.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Contract.Lock", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        Request := Fixture.Request(Header, false);
        Response := Data.Invoke("Message Type ori"::"Service.Contract.Lock", Request, Other."Contract No.", 1033, false);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        Clear(Request);
        Response := Data.Invoke("Message Type ori"::"Service.Contract.Lock", Request, Header."Contract No.", 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Plain subject supported.');
        Other.Get(Other."Contract Type", Other."Contract No.");
        Assert.AreEqual(Other."Change Status"::Open, Other."Change Status", 'Other contract unchanged.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_BadBooleanAndWrongScope()
    var
        Header: Record "Service Contract Header";
        Request: JsonObject;
        Response: JsonObject;
        Name: Text;
    begin
        // Story #24 AC04 | Risk: a string false is silently interpreted as true.
        Fixture.Create(Header, true);
        Commit();
        foreach Name in 'createInvoice,addLinesStartingLater,acceptMissingServiceDate,acceptNonMonthEndInvoiceDate'.Split(',') do begin
            Request := Fixture.Request(Header, true);
            if Request.Contains(Name) then
                Request.Replace(Name, 'false')
            else
                Request.Add(Name, 'false');
            Response := Data.Invoke("Message Type ori"::"Service.ContractQuote.MakeContract", Request, '', 1033, false);
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
        end;
        Clear(Request);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Response := Data.Invoke("Message Type ori"::"Service.Contract.Lock", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.IsTrue(Header.Get(Header."Contract Type", Header."Contract No."), 'Quote unchanged.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC05_ChangeStatusRefusedWithDedicatedHint()
    var
        Header: Record "Service Contract Header";
        Request: JsonObject;
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
        Response: JsonObject;
        Serialized: Text;
    begin
        // Story #24 AC05 | Risk: generic writes bypass the dedicated native action.
        Fixture.Create(Header, false);
        Fields.Add('Change Status', 'Locked');
        Entry.Add('id', Format(Header.SystemId, 0, 4));
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Request.Add('tableName', 'Service Contract Header');
        Request.Add('data', Entries);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'PermissionDenied');
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('Service.Contract.Lock / Service.Contract.Unlock'), 'Hint names dedicated actions.');
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(Header."Change Status"::Open, Header."Change Status", 'No generic mutation.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC05_NativeStatusValidationRefusesSigning()
    var
        Header: Record "Service Contract Header";
    begin
        // Story #24 AC05 | Risk: Status validation creates a signed contract without native signing.
        Fixture.Create(Header, false);
        Commit();
        asserterror Header.Validate(Status, Header.Status::Signed);
        Header.Get(Header."Contract Type", Header."Contract No.");
        Assert.AreEqual(Header.Status::" ", Header.Status, 'Native validation already blocks direct signing.');
        Fixture.Cleanup();
    end;
}
