namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Reads back the Service.FaultResolution.Suggest help in 1033 and 1039 and checks the public wording.</summary>
codeunit 97792 "Svc Fault Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC07_Contract_ReadEffectAllChapters_BothLanguages()
    var
        Chapters: List of [Text];
        Chapter: Text;
        Forbidden: Text;
        Language: Integer;
        Languages: List of [Integer];
        Contract: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        Chapters := 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|');
        Languages.Add(1033);
        Languages.Add(1039);
        foreach Language in Languages do begin
            Contract := ReadContract(Language, Serialized);
            foreach Chapter in Chapters do
                Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
            Contract.Get('effect', Token);
            Assert.AreEqual('read', Data.TextValue(Token.AsObject(), 'effect'), 'Suggest is a read.');
            foreach Forbidden in OwnTexts(Contract) do begin
                Assert.IsFalse(LowerCase(Forbidden).Contains('message type'), 'Help must not say message type: ' + Forbidden);
                Assert.IsFalse(Forbidden.Contains(' ori'), 'Help must not name AL objects: ' + Forbidden);
                Assert.IsFalse(LowerCase(Forbidden).Contains('codeunit'), 'Help must not name codeunits: ' + Forbidden);
            end;
            foreach Chapter in 'faultCode|symptomCode|faultAreaCode|serviceItemGroupCode|serviceItemLineNo|top|PreconditionFailed|ConflictingIdentifiers'.Split('|') do
                Assert.IsTrue(Serialized.Contains(Chapter), 'Help documents ' + Chapter);
        end;
    end;

    [Test]
    procedure Scenario_AC07_Discovery_EnglishAndIcelandic()
    var
        Discovery: Interface "Msg Discovery ori";
        Implementation: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        English: Text;
        Icelandic: Text;
        EnglishKeywords: Text;
        IcelandicKeywords: Text;
        PriorLanguage: Integer;
    begin
        PriorLanguage := GlobalLanguage();
        MessageType := "Message Type ori"::"Service.FaultResolution.Suggest";
        Discovery := MessageType;
        Implementation := MessageType;
        GlobalLanguage(1033);
        English := Implementation.GetDescription();
        EnglishKeywords := Discovery.GetKeywords();
        GlobalLanguage(1039);
        Icelandic := Implementation.GetDescription();
        IcelandicKeywords := Discovery.GetKeywords();
        GlobalLanguage(PriorLanguage);
        Assert.IsTrue(English.StartsWith('Suggests the resolution codes'), 'English description.');
        Assert.IsTrue(Icelandic.StartsWith('Stingur upp á lausnarkóðum'), 'Icelandic description.');
        Assert.AreEqual('villukóði, lausnarkóði, tillaga að lagfæringu, viðgerðarsaga', IcelandicKeywords, 'Icelandic keywords.');
        Assert.AreEqual(EnglishKeywords.Split(',').Count(), IcelandicKeywords.Split(',').Count(), 'Keyword count.');
    end;

    [Test]
    procedure Scenario_AC07_Refusal_TranslatedIn1039()
    var
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        Request.Add('top', 5);
        English := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Icelandic := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1039, false);
        Data.AssertRefusal(English, 'MissingParameter');
        Data.AssertRefusal(Icelandic, 'MissingParameter');
        Assert.IsTrue(Data.TextValue(English, 'error').StartsWith('Send a service item line'), 'English refusal.');
        Assert.IsTrue(Data.TextValue(Icelandic, 'error').StartsWith('Sendu þjónustuvörulínu'), 'Icelandic refusal: ' + Data.TextValue(Icelandic, 'error'));
        Assert.IsTrue(Data.TextValue(Icelandic, 'nextStep').StartsWith('Lestu þjónustuvörulínurnar'), 'Icelandic nextStep: ' + Data.TextValue(Icelandic, 'nextStep'));
    end;

    local procedure ReadContract(Language: Integer; var Serialized: Text): JsonObject
    var
        Request: JsonObject;
        Names: JsonArray;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Names.Add('Service.FaultResolution.Suggest');
        Request.Add('messageTypes', Names);
        Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, '', Language, true);
        Response.WriteTo(Serialized);
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        exit(Token.AsObject());
    end;

    /// <summary>Collects this app's own help text: parameter, field and error descriptions, effect, notes and overview.</summary>
    local procedure OwnTexts(Contract: JsonObject): List of [Text]
    var
        Texts: List of [Text];
        Token: JsonToken;
        Item: JsonToken;
        Value: JsonToken;
        Name: Text;
    begin
        foreach Item in ChapterArray(Contract, 'parameters') do
            if Item.AsObject().Get('description', Value) then
                Texts.Add(Value.AsValue().AsText());
        if Contract.Get('response', Token) then
            if Token.AsObject().Get('fields', Token) then
                foreach Item in Token.AsArray() do
                    if Item.AsObject().Get('description', Value) then
                        Texts.Add(Value.AsValue().AsText());
        if Contract.Get('effect', Token) then
            if Token.AsObject().Get('changes', Value) then
                Texts.Add(Value.AsValue().AsText());
        foreach Name in 'notes|overview'.Split('|') do
            if Contract.Get(Name, Value) then
                if Value.IsValue() then
                    Texts.Add(Value.AsValue().AsText());
        exit(Texts);
    end;

    local procedure ChapterArray(Contract: JsonObject; Name: Text): JsonArray
    var
        Token: JsonToken;
        Empty: JsonArray;
    begin
        if Contract.Get(Name, Token) then
            if Token.IsArray() then
                exit(Token.AsArray());
        exit(Empty);
    end;
}
