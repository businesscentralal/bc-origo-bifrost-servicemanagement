namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Checks the public contracts, the commit statement and the bilingual catalogue texts.</summary>
codeunit 97745 "Svc Post Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC16_PostContract_HasAllChapters_AndCommits()
    begin
        CheckContract('Service.Order.Post', 'irreversible', true);
    end;

    [Test]
    procedure Scenario_AC16_PreviewContract_HasAllChapters_AndIsRead()
    begin
        CheckContract('Service.Order.PreviewPost', 'read', false);
    end;

    [Test]
    procedure Scenario_AC18_Catalogue_BothLanguages()
    var
        Discovery: Interface "Msg Discovery ori";
        English: Text;
        Icelandic: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        Discovery := "Message Type ori"::"Service.Order.Post";
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(English.Contains('post service order'), 'English keyword.');
        Assert.IsTrue(Icelandic.Contains('bóka þjónustupöntun'), 'Icelandic keyword.');
        Assert.IsTrue(Icelandic.Split(',').Count() >= English.Split(',').Count(), 'Icelandic keyword count.');
    end;

    local procedure CheckContract(TypeName: Text; Effect: Text; Commits: Boolean)
    var
        Request: JsonObject;
        Names: JsonArray;
        Response: JsonObject;
        Contract: JsonObject;
        Token: JsonToken;
        Chapters: List of [Text];
        Chapter: Text;
        Serialized: Text;
    begin
        Chapters := 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|');
        Names.Add(TypeName);
        Request.Add('messageTypes', Names);
        Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, '', 1033, true);
        Response.WriteTo(Serialized);
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Contract := Token.AsObject();
        foreach Chapter in Chapters do
            Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
        Contract.Get('effect', Token);
        Assert.AreEqual(Effect, Data.TextValue(Token.AsObject(), 'effect'), 'Effect.');
        if Commits then begin
            Assert.IsTrue(Serialized.Contains('This call commits'), 'Commit is documented.');
            Assert.IsTrue(Serialized.Contains('expectedCount'), 'The count parameter is described.');
            Assert.IsTrue(Serialized.Contains('ConfirmationRequired'), 'ConfirmationRequired is described.');
            Assert.IsTrue(Serialized.Contains('ConfirmationMismatch'), 'ConfirmationMismatch is described.');
            Assert.IsTrue(Serialized.Contains('PermissionDenied'), 'PermissionDenied is described.');
        end;
        Assert.IsTrue(Serialized.Contains('PreconditionFailed'), 'PreconditionFailed is described.');
    end;
}
