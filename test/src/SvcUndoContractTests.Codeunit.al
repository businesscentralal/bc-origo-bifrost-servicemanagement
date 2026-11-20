namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Checks the help chapters of both undo types and their bilingual catalogue texts.</summary>
codeunit 97753 "Svc Undo Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC07_ShipmentUndo_Help_1033_1039()
    begin
        CheckContract('Service.Shipment.Undo', 1033);
        CheckContract('Service.Shipment.Undo', 1039);
        CheckCatalogue("Message Type ori"::"Service.Shipment.Undo", 'undo service shipment', 'afturkalla þjónustuafhendingu');
    end;

    [Test]
    procedure Scenario_AC07_ConsumptionUndo_Help_1033_1039()
    begin
        CheckContract('Service.Consumption.Undo', 1033);
        CheckContract('Service.Consumption.Undo', 1039);
        CheckCatalogue("Message Type ori"::"Service.Consumption.Undo", 'undo service consumption', 'afturkalla þjónustunotkun');
    end;

    local procedure CheckContract(TypeName: Text; LanguageId: Integer)
    var
        Request: JsonObject;
        Names: JsonArray;
        Response: JsonObject;
        Contract: JsonObject;
        Token: JsonToken;
        Chapter: Text;
        Serialized: Text;
        Forbidden: Text;
        Own: Text;
    begin
        Names.Add(TypeName);
        Request.Add('messageTypes', Names);
        Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, '', LanguageId, true);
        Response.WriteTo(Serialized);
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Contract := Token.AsObject();
        foreach Chapter in 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|') do
            Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
        Contract.Get('effect', Token);
        Assert.AreEqual('irreversible', Data.TextValue(Token.AsObject(), 'effect'), 'Effect.');
        foreach Chapter in 'This call commits|a later caller error rolls the undo back|lineNos|expectedCount|ConfirmationRequired|ConfirmationMismatch|PermissionDenied|PreconditionFailed|RecordNotFound|ConflictingIdentifiers|InvalidParameterFormat'.Split('|') do
            Assert.IsTrue(Serialized.Contains(Chapter), 'Help names ' + Chapter);
        // Only the chapters this app writes; Foundation's own wrapper text is not part of this help.
        foreach Chapter in 'target|parameters|response|errors|effect|related|examples|overview|notes'.Split('|') do begin
            Contract.Get(Chapter, Token);
            Token.WriteTo(Own);
            foreach Forbidden in 'message type|Codeunit|codeunit|Undo Service Shipment Line|Undo Service Consumption Line|Svc Undo'.Split('|') do
                Assert.IsFalse(Own.Contains(Forbidden), 'Help chapter ' + Chapter + ' must not name ' + Forbidden);
        end;
    end;

    local procedure CheckCatalogue(MessageType: Enum "Message Type ori"; EnglishKeyword: Text; IcelandicKeyword: Text)
    var
        Discovery: Interface "Msg Discovery ori";
        Implementation: Interface "Msg Interface ori";
        English: Text;
        Icelandic: Text;
        EnglishDescription: Text;
        IcelandicDescription: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        Discovery := MessageType;
        Implementation := MessageType;
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        EnglishDescription := Implementation.GetDescription();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        IcelandicDescription := Implementation.GetDescription();
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(English.Contains(EnglishKeyword), 'English keyword.');
        Assert.IsTrue(Icelandic.Contains(IcelandicKeyword), 'Icelandic keyword: ' + Icelandic);
        Assert.AreNotEqual(EnglishDescription, IcelandicDescription, 'The description is translated.');
        Assert.IsTrue(IcelandicDescription.Contains('Afturkallar'), 'Icelandic description: ' + IcelandicDescription);
    end;
}
