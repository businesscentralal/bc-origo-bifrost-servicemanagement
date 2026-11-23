namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves the full role adjusts prices and the read role and a user without any Bifröst set are refused with nothing changed.</summary>
codeunit 97771 "Svc Price Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";
        Price: Codeunit "Svc Price Adjust Tests ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC05_FullRole_Adjusts()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
    begin
        // [GIVEN] A self-made adjustable order
        Price.CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 0, 200);
        Commit();

        // [WHEN] A Bifröst full-role user with service edit access adjusts the price
        Response := RunAs('BIFROST Full ori', Price.LineRequest(ItemLine));

        // [THEN] The adjustment succeeds
        Price.AssertSuccess(Response);
        Assert.AreEqual(200, Price.LinesTotal(ItemLine), 'Full role adjusts.');
    end;

    [Test]
    procedure Scenario_AC05_ReadRole_Refused()
    begin
        AssertRefused('BIFROST Read ori', false);
        AssertRefused('BIFROST Read ori', true);
    end;

    [Test]
    procedure Scenario_AC05_NoPermission_Refused()
    begin
        AssertRefused('', false);
    end;

    local procedure AssertRefused(RoleSet: Text; Preview: Boolean)
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Request: JsonObject;
        Response: JsonObject;
        Before: Decimal;
    begin
        Price.CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 0, 200);
        Before := Price.LinesTotal(ItemLine);
        Request := Price.LineRequest(ItemLine);
        if Preview then
            Request.Add('preview', true);
        Commit();
        Response := RunAs(RoleSet, Request);
        if Response.Keys().Count() > 0 then
            Data.AssertRefusal(Response, 'PermissionDenied')
        else
            Assert.IsTrue(GetLastErrorText().Contains('permission') or GetLastErrorText().Contains('Permission'), 'Platform must deny execution: ' + GetLastErrorText());
        Assert.AreEqual(Before, Price.LinesTotal(ItemLine), 'Nothing changed.');
        Assert.AreEqual(0, Price.AdjustedCount(ItemLine), 'No line marked.');
    end;

    local procedure RunAs(RoleSet: Text; Request: JsonObject): JsonObject
    var
        Runner: Codeunit "Svc Price Perm Runner ori";
        Empty: JsonObject;
        Response: JsonObject;
        Succeeded: Boolean;
    begin
        ClearLastError();
        if RoleSet <> '' then
            LowerPermissions.SetExactPermissionSet(CopyStr(RoleSet, 1, 20))
        else
            LowerPermissions.SetExactPermissionSet('Svc NoGrant Tst ori');
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
        Runner.SetRequest(Request);
        Succeeded := Runner.Run();
        if Succeeded then
            Response := Runner.GetResponse();
        LowerPermissions.SetOutsideO365Scope();
        if Succeeded then
            exit(Response);
        exit(Empty);
    end;
}
