namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.Environment;
using System.TestLibraries.Utilities;

/// <summary>Checks public contract completeness, stable names and bilingual refusals.</summary>
codeunit 97708 "Svc Release Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC11_BothContracts_HaveAllChaptersAndWriteEffect()
    var
        Types: List of [Enum "Message Type ori"];
        MessageType: Enum "Message Type ori";
        Chapters: List of [Text];
        Chapter: Text;
        Request: JsonObject;
        Names: JsonArray;
        Response: JsonObject;
        Contract: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        // Story #4 AC11: invoke Help through the same public dispatcher as callers.
        Types.Add("Message Type ori"::"Service.Order.Release");
        Types.Add("Message Type ori"::"Service.Order.Reopen");
        Chapters := 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|');
        foreach MessageType in Types do begin
            Clear(Request);
            Clear(Names);
            Names.Add(MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger())));
            Request.Add('messageTypes', Names);
            Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, '', 1033, true);
            Response.WriteTo(Serialized);
            Assert.IsTrue(Serialized.Contains('Retryable'), 'Foundation augments write errors with Retryable.');
            Response.Get('result', Token);
            Token.AsArray().Get(0, Token);
            Contract := Token.AsObject();
            foreach Chapter in Chapters do
                Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
            Contract.Get('effect', Token);
            Assert.AreEqual('write', Data.TextValue(Token.AsObject(), 'effect'), 'No posting effect.');
        end;
    end;

    [Test]
    procedure Scenario_AC13_Catalogue_BothLanguages()
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        English: Text;
        Icelandic: Text;
        PriorLanguage: Integer;
    begin
        // Story #4 AC13: discovery is the catalogue interface; no customer data involved.
        PriorLanguage := GlobalLanguage();
        MessageType := "Message Type ori"::"Service.Order.Release";
        Discovery := MessageType;
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        GlobalLanguage(PriorLanguage);
        Assert.AreNotEqual(English, Icelandic, 'Keywords must be localized.');
        Assert.IsTrue(Icelandic.Split(',').Count() >= English.Split(',').Count(), 'Icelandic keyword count.');
    end;

    [Test]
    procedure Scenario_AC12_NewOrdinaryCompany_RequiresEula()
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
        // Story #4 AC12: actual ordinary company, not a spoofed platform flag or mutated consent setup.
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
        Responses.Get('release', Response);
        Response.AsObject().Get('code', ErrorCode);
        Assert.AreEqual('EULA_REQUIRED', ErrorCode.AsValue().AsText(), 'Release must refuse consent before order lookup.');
        Responses.Get('reopen', Response);
        Response.AsObject().Get('code', ErrorCode);
        Assert.AreEqual('EULA_REQUIRED', ErrorCode.AsValue().AsText(), 'Reopen must refuse consent before order lookup.');
    end;
}
