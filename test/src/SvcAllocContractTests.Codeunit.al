namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.Environment;
using System.TestLibraries.Utilities;

/// <summary>Checks the allocation contract, bilingual catalogue and unlicensed refusal.</summary>
codeunit 97728 "Svc Alloc Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_Contract_HasChaptersWriteEffectAndRetryable()
    var
        Chapters: List of [Text];
        Chapter: Text;
        Request: JsonObject;
        Names: JsonArray;
        Response: JsonObject;
        Contract: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        Chapters := 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|');
        Names.Add('Service.Allocation.Allocate');
        Request.Add('messageTypes', Names);
        Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, '', 1033, true);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('Retryable'), 'Foundation augments write errors with Retryable.');
        Assert.IsTrue(Serialized.Contains('acceptOutsideServiceZone'), 'Zone acknowledgment is declared.');
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Contract := Token.AsObject();
        foreach Chapter in Chapters do
            Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
        Contract.Get('effect', Token);
        Assert.AreEqual('write', Data.TextValue(Token.AsObject(), 'effect'), 'Allocation is a write.');
        Token.AsObject().Get('idempotent', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Allocation is not idempotent.');
    end;

    [Test]
    procedure Scenario_Catalogue_BothLanguages()
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        English: Text;
        Icelandic: Text;
        PriorLanguage: Integer;
    begin
        PriorLanguage := GlobalLanguage();
        MessageType := "Message Type ori"::"Service.Allocation.Allocate";
        Discovery := MessageType;
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        Assert.AreEqual('allocate resource, assign technician, reallocate', English, 'English keywords.');
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        GlobalLanguage(PriorLanguage);
        Assert.AreEqual('úthluta forða, úthluta tæknimanni, endurúthluta', Icelandic, 'Icelandic keywords.');
        Assert.IsTrue(Icelandic.Split(',').Count() >= English.Split(',').Count(), 'Icelandic keyword count.');
    end;

    [Test]
    procedure Scenario_NewOrdinaryCompany_RequiresEula()
    var
        Company: Record Company;
        Result: Record "Svc Licence Result Tst ori";
        ResponseText: Text;
        Responses: JsonObject;
        Response: JsonToken;
        ErrorCode: JsonToken;
        CompanyName: Text[30];
        SessionId: Integer;
        Attempts: Integer;
        Finished: Boolean;
        Started: Boolean;
        Input: InStream;
    begin
        CompanyName := CopyStr('X-SVC-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 30);
        Company.Init();
        Company.Name := CompanyName;
        Company.Insert(true);
        Result.Id := CreateGuid();
        Result.Insert();
        Commit();
        Started := StartSession(SessionId, Codeunit::"Svc Licence Probe Tst ori", CompanyName, Result);
        if Started then
            repeat
                Sleep(500);
                Result.Get(Result.Id);
                Finished := Result.Completed;
                Attempts += 1;
            until Finished or (Attempts >= 120);
        if Started and not Finished then
            StopSession(SessionId);
        if Finished then begin
            Result.CalcFields(Response);
            Result.Response.CreateInStream(Input, TextEncoding::UTF8);
            Input.ReadText(ResponseText);
        end;
        Result.Delete();
        Company.Get(CompanyName);
        Company.Delete();
        Commit();
        Assert.IsTrue(Started and Finished, 'Owned licence probe must finish and return a response.');
        Responses.ReadFrom(ResponseText);
        Responses.Get('allocate', Response);
        Response.AsObject().Get('code', ErrorCode);
        Assert.AreEqual('EULA_REQUIRED', ErrorCode.AsValue().AsText(), 'Allocate must refuse consent before order lookup.');
    end;
}
