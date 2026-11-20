namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Service.Resource.Suggest is a read: the Bifrost read role succeeds without SUPER, a user without service read access is refused (#27 AC05).</summary>
codeunit 97781 "Svc Suggest Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Fixture: Codeunit "Svc Suggest Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC05_ReadRole_Succeeds()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        OldSkills: Option "Code Shown","Warning Displayed","Not Used";
        OldZones: Option "Code Shown","Warning Displayed","Not Used";
    begin
        Request := Prepare(OldSkills, OldZones);
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365 READ');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        LowerPermissions.SetOutsideO365Scope();
        Fixture.RestoreOptions(OldSkills, OldZones);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'The read role ranks resources.');
        Response.Get('resources', Token);
        Assert.AreEqual(3, Token.AsArray().Count(), 'The read role sees the qualified resources.');
    end;

    [Test]
    procedure Scenario_AC05_NoServiceRead_PermissionDenied()
    var
        Request: JsonObject;
        Response: JsonObject;
        OldSkills: Option "Code Shown","Warning Displayed","Not Used";
        OldZones: Option "Code Shown","Warning Displayed","Not Used";
    begin
        Request := Prepare(OldSkills, OldZones);
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        LowerPermissions.SetOutsideO365Scope();
        Fixture.RestoreOptions(OldSkills, OldZones);
        Data.AssertRefusal(Response, 'PermissionDenied');
    end;

    local procedure Prepare(var OldSkills: Option "Code Shown","Warning Displayed","Not Used"; var OldZones: Option "Code Shown","Warning Displayed","Not Used") Request: JsonObject
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        GroupNo: Code[20];
        Qualified: Code[20];
        Remote: Code[20];
        Busy: Code[20];
        Unskilled: Code[20];
        FirstDay: Date;
    begin
        FirstDay := DMY2Date(2, 3, 2026);
        Fixture.Create(Header, ItemLine, GroupNo, Qualified, Remote, Busy, Unskilled, FirstDay);
        Fixture.SetOptions(OldSkills::"Code Shown", OldZones::"Code Shown", OldSkills, OldZones);
        Request.Add('documentNo', Header."No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No.");
        Request.Add('resourceGroupNo', GroupNo);
        Request.Add('dateFrom', Format(FirstDay, 0, 9));
        Request.Add('dateTo', Format(FirstDay + 1, 0, 9));
        Commit();
    end;
}
