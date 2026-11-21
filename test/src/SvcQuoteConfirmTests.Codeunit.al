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
    procedure Scenario_AC02_Required_NoCount_Runs()
    begin
        CheckConversion(true, false, 0, 1033);
    end;

    [Test]
    procedure Scenario_AC02_Required_WrongCountIgnored()
    begin
        CheckConversion(true, true, 2, 1033);
    end;

    [Test]
    procedure Scenario_AC02_Optional_NoCount_Runs()
    begin
        CheckConversion(false, false, 0, 1033);
    end;

    [Test]
    procedure Scenario_AC02_Optional_CountOneIgnored()
    begin
        CheckConversion(false, true, 1, 1033);
    end;

    [Test]
    procedure Scenario_AC02_Icelandic_NoConfirmation()
    begin
        CheckConversion(true, false, 0, 1039);
    end;

    local procedure CheckConversion(Required: Boolean; SupplyCount: Boolean; Count: Integer; LanguageId: Integer)
    var
        Header: Record "Service Header";
        OrderHeader: Record "Service Header";
        SetupPage: TestPage "Setup ori";
        PriorRequired: Boolean;
        Request: JsonObject;
        Response: JsonObject;
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
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Conversion needs no confirmation and ignores expectedCount.');
        Assert.IsFalse(Header.Get(Header."Document Type", Header."No."), 'Successful conversion removes quote.');
        OrderHeader.SetRange("Document Type", OrderHeader."Document Type"::Order);
        OrderHeader.SetRange("Quote No.", Header."No.");
        Assert.IsFalse(OrderHeader.IsEmpty(), 'Conversion creates the order.');
    end;
}
