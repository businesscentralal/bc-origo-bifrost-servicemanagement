namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves the Foundation confirmation count protects the irreversible posting.</summary>
codeunit 97742 "Svc Post Confirm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC09_MissingCount_ConfirmationRequired()
    begin
        CheckRefusal(0, 'ConfirmationRequired', 1033, 'service order');
    end;

    [Test]
    procedure Scenario_AC09_WrongCount_ConfirmationMismatch()
    begin
        CheckRefusal(2, 'ConfirmationMismatch', 1033, '');
    end;

    [Test]
    procedure Scenario_AC18_Icelandic_ConfirmationSummary()
    begin
        CheckRefusal(0, 'ConfirmationRequired', 1039, 'þjónustupöntun');
    end;

    local procedure CheckRefusal(Count: Integer; Expected: Text; LanguageId: Integer; SummaryText: Text)
    var
        Header: Record "Service Header";
        Response: JsonObject;
        Serialized: Text;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Response := PostData.Post(Header."No.", 'true', '', 'true', Count, LanguageId);
        Data.AssertRefusal(Response, Expected);
        Response.WriteTo(Serialized);
        if SummaryText <> '' then
            Assert.IsTrue(Serialized.Contains(SummaryText), 'The summary names the order in the caller language.');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Nothing is posted.');
    end;
}
