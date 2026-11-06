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

    [Test]
    procedure Scenario_AC09_Optional_MissingCount_Posts()
    begin
        CheckOptional(0, 'Success');
    end;

    [Test]
    procedure Scenario_AC09_Optional_WrongCount_Refuses()
    begin
        CheckOptional(2, 'ConfirmationMismatch');
    end;

    local procedure CheckOptional(Count: Integer; Expected: Text)
    var
        Header: Record "Service Header";
        SetupPage: TestPage "Setup ori";
        Response: JsonObject;
        PriorRequired: Boolean;
    begin
        // Story #7 AC09 | Time: WorkDate for posting | Risk: administrator preference is restored after invocation.
        PostData.CreateOrder(Header);
        SetupPage.OpenEdit();
        PriorRequired := SetupPage."Require Irreversible Confirm".AsBoolean();
        SetupPage."Require Irreversible Confirm".SetValue(false);
        SetupPage.Close();
        Commit();
        Response := PostData.Post(Header."No.", 'true', '', 'true', Count, 1033);
        SetupPage.OpenEdit();
        SetupPage."Require Irreversible Confirm".SetValue(PriorRequired);
        SetupPage.Close();
        Commit();
        if Expected = 'Success' then begin
            PostData.AssertSuccess(Response);
            Assert.AreEqual(1, PostData.PostedInvoices(Header."No."), 'Optional omission posts.');
        end else begin
            Data.AssertRefusal(Response, Expected);
            Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Supplied stale count still posts nothing.');
        end;
    end;

    local procedure CheckRefusal(Count: Integer; Expected: Text; LanguageId: Integer; SummaryText: Text)
    var
        Header: Record "Service Header";
        Response: JsonObject;
        Serialized: Text;
        SetupPage: TestPage "Setup ori";
        PriorRequired: Boolean;
    begin
        PostData.CreateOrder(Header);
        SetupPage.OpenEdit();
        PriorRequired := SetupPage."Require Irreversible Confirm".AsBoolean();
        SetupPage."Require Irreversible Confirm".SetValue(true);
        SetupPage.Close();
        Commit();
        Response := PostData.Post(Header."No.", 'true', '', 'true', Count, LanguageId);
        SetupPage.OpenEdit();
        SetupPage."Require Irreversible Confirm".SetValue(PriorRequired);
        SetupPage.Close();
        Commit();
        Data.AssertRefusal(Response, Expected);
        Response.WriteTo(Serialized);
        if SummaryText <> '' then
            Assert.IsTrue(Serialized.Contains(SummaryText), 'The summary names the order in the caller language.');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Nothing is posted.');
    end;
}
