namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Setup;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves the Foundation confirmation setting and count guard preserve quotes on refusal.</summary>
codeunit 97716 "Svc Quote Confirm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC03_Required_MissingCount()
    begin
        CheckConfirmation(true, false, 0, 'ConfirmationRequired', 1033);
    end;

    [Test]
    procedure Scenario_AC03_Required_WrongCount()
    begin
        CheckConfirmation(true, true, 2, 'ConfirmationMismatch', 1033);
    end;

    [Test]
    procedure Scenario_AC03_Optional_OmissionRuns()
    begin
        CheckConfirmation(false, false, 0, 'Success', 1033);
    end;

    [Test]
    procedure Scenario_AC03_Optional_WrongCountStillRefuses()
    begin
        CheckConfirmation(false, true, 0, 'ConfirmationMismatch', 1033);
    end;

    [Test]
    procedure Scenario_AC14_Icelandic_ConfirmationSummary()
    begin
        CheckConfirmation(true, false, 0, 'ConfirmationRequired', 1039);
    end;

    local procedure CheckConfirmation(Required: Boolean; SupplyCount: Boolean; Count: Integer; Expected: Text; LanguageId: Integer)
    var
        Header: Record "Service Header";
        OrderHeader: Record "Service Header";
        SetupPage: TestPage "Setup ori";
        PriorRequired: Boolean;
        Request: JsonObject;
        Response: JsonObject;
        Text: Text;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        SetupPage.OpenEdit();
        PriorRequired := SetupPage."Require Irreversible Confirm".AsBoolean();
        SetupPage."Require Irreversible Confirm".SetValue(Required);
        SetupPage.Close();
        Request.Add('no', Header."No.");
        if SupplyCount then
            Request.Add('expectedCount', Count);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Quote.MakeOrder", Request, '', LanguageId, false);
        SetupPage.OpenEdit();
        SetupPage."Require Irreversible Confirm".SetValue(PriorRequired);
        SetupPage.Close();
        Commit();
        if Expected = 'Success' then begin
            Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Administrator may turn required count off.');
            Assert.IsFalse(Header.Get(Header."Document Type", Header."No."), 'Successful conversion removes quote.');
            exit;
        end;
        Data.AssertRefusal(Response, Expected);
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'Refusal retains quote.');
        OrderHeader.SetRange("Document Type", OrderHeader."Document Type"::Order);
        OrderHeader.SetRange("Quote No.", Header."No.");
        Assert.IsTrue(OrderHeader.IsEmpty(), 'Refusal creates no order.');
        if Expected = 'ConfirmationRequired' then begin
            Response.WriteTo(Text);
            Assert.IsTrue(Text.Contains(Header."No."), 'Summary identifies the quote.');
            if LanguageId = 1039 then
                Assert.IsTrue(Text.Contains('þjónustutilboð'), 'Icelandic confirmation summary.');
        end;
    end;
}
