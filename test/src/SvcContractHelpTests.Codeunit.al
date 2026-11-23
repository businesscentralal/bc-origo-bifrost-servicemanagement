namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 24 contract help, localized discovery and refusal guidance.</summary>
codeunit 97767 "Svc Contract Help Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC07_AllContractsInBothLanguages()
    var
        Types: List of [Enum "Message Type ori"];
        TypeValue: Enum "Message Type ori";
        Contract: Interface "Msg Contract ori";
        Discovery: Interface "Msg Discovery ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Errors: JsonArray;
        Examples: JsonArray;
        Notes: Text;
        Overview: Text;
        Serialized: Text;
        English: Text;
        PreviousLanguage: Integer;
        LanguageId: Integer;
        Pass: Integer;
    begin
        // Story #24 AC07 | Risk: public help leaks implementation names or omits localized discovery.
        Types.Add("Message Type ori"::"Service.ContractQuote.MakeContract");
        Types.Add("Message Type ori"::"Service.Contract.Sign");
        Types.Add("Message Type ori"::"Service.Contract.Lock");
        Types.Add("Message Type ori"::"Service.Contract.Unlock");
        PreviousLanguage := GlobalLanguage();
        foreach TypeValue in Types do begin
            Contract := TypeValue;
            Discovery := TypeValue;
            for Pass := 1 to 2 do begin
                LanguageId := 1033;
                if Pass = 2 then
                    LanguageId := 1039;
                GlobalLanguage(LanguageId);
                Clear(Effect);
                Clear(Parameters);
                Clear(Errors);
                Clear(Examples);
                Assert.IsTrue(Contract.GetEffect(Effect), 'Effect chapter.');
                Assert.AreEqual('write', Data.TextValue(Effect, 'effect'), 'Only posting is irreversible (#43).');
                Assert.IsTrue(Contract.GetParameters(Parameters), 'Parameters chapter.');
                Assert.IsTrue(Contract.GetErrors(Errors), 'Errors chapter.');
                Assert.IsTrue(Contract.GetExamples(Examples), 'Examples chapter.');
                Assert.IsTrue(Contract.GetNotes(Notes), 'Notes chapter.');
                Assert.IsTrue(Contract.GetOverview(Overview), 'Overview chapter.');
                Errors.WriteTo(Serialized);
                Serialized := LowerCase(Serialized + Notes + Overview);
                Assert.IsFalse(Serialized.Contains('codeunit') or Serialized.Contains('message type') or Serialized.Contains('signservcontractdoc'), 'No implementation names in public help.');
                if Pass = 1 then
                    English := Discovery.GetSelectionDescription()
                else
                    Assert.AreNotEqual(English, Discovery.GetSelectionDescription(), 'Icelandic discovery translated.');
            end;
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC07_RefusalsAreLocalized()
    var
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        // Story #24 AC07 | Risk: GlobalLanguage is ignored by new refusal labels.
        English := Data.Invoke("Message Type ori"::"Service.Contract.Sign", Request, '', 1033, false);
        Icelandic := Data.Invoke("Message Type ori"::"Service.Contract.Sign", Request, '', 1039, false);
        Data.AssertRefusal(English, 'MissingParameter');
        Data.AssertRefusal(Icelandic, 'MissingParameter');
        Assert.AreNotEqual(Data.TextValue(English, 'error'), Data.TextValue(Icelandic, 'error'), 'Localized error.');
        Assert.AreNotEqual(Data.TextValue(English, 'nextStep'), Data.TextValue(Icelandic, 'nextStep'), 'Localized recovery.');
    end;
}
