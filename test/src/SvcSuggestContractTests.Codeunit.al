namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Service.Resource.Suggest help, catalogue and refusal language (#27 AC06).</summary>
codeunit 97782 "Svc Suggest Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC06_Help_ReadEffect_BothLanguages()
    begin
        AssertHelp(1033);
        AssertHelp(1039);
    end;

    [Test]
    procedure Scenario_AC06_Catalogue_BothLanguages()
    var
        Discovery: Interface "Msg Discovery ori";
        Implementation: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        English: Text;
        Icelandic: Text;
        EnglishDescription: Text;
        IcelandicDescription: Text;
        PriorLanguage: Integer;
    begin
        PriorLanguage := GlobalLanguage();
        MessageType := "Message Type ori"::"Service.Resource.Suggest";
        Discovery := MessageType;
        Implementation := MessageType;
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        EnglishDescription := Implementation.GetDescription();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        IcelandicDescription := Implementation.GetDescription();
        GlobalLanguage(PriorLanguage);
        Assert.AreEqual('suggest resource, qualified technician, available resource, dispatch', English, 'English keywords.');
        Assert.AreEqual('stinga upp á forða, hæfur tæknimaður, laus forði, útdeiling verka', Icelandic, 'Icelandic keywords.');
        Assert.IsTrue(IcelandicDescription.Contains('þjónustuvörulínu'), 'Icelandic description.');
        Assert.AreNotEqual(EnglishDescription, IcelandicDescription, 'The description is translated.');
    end;

    [Test]
    procedure Scenario_AC06_Refusal_Icelandic()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1039, false);
        Data.AssertRefusal(Response, 'MissingParameter');
        Assert.AreEqual('Sendu documentNo ásamt serviceItemLineNo, eða systemId þjónustuvörulínu.', Data.TextValue(Response, 'error'), 'Icelandic refusal.');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, false);
        Assert.AreEqual('Send documentNo with serviceItemLineNo, or systemId of a service item line.', Data.TextValue(Response, 'error'), 'English refusal.');
    end;

    local procedure AssertHelp(LanguageId: Integer)
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
        Names.Add('Service.Resource.Suggest');
        Request.Add('messageTypes', Names);
        Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, '', LanguageId, true);
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Contract := Token.AsObject();
        foreach Chapter in Chapters do
            Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
        Contract.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('Service.Allocation.Allocate'), 'Help names the next step.');
        Assert.IsTrue(Serialized.Contains('includeUnqualified'), 'Parameters are declared.');
        Assert.IsFalse(Serialized.ToLower().Contains('codeunit'), 'Help names no AL objects.');
        Assert.IsFalse(Serialized.ToLower().Contains('message type'), 'Help does not say message type.');
        Assert.IsFalse(Serialized.Contains('Svc Resource Suggest'), 'Help names no AL objects.');
        Assert.IsFalse(Serialized.Contains('ServAllocationManagement'), 'Help names no AL objects.');
        Contract.Get('effect', Token);
        Assert.AreEqual('read', Data.TextValue(Token.AsObject(), 'effect'), 'Suggest is a read.');
    end;
}
