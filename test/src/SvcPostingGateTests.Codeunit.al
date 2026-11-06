namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using Origo.Bifrost.ServiceManagement;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves the posting token set gates Service.Order.Post and is not part of the full or read roles.</summary>
codeunit 97743 "Svc Posting Gate Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        PostData: Codeunit "Svc Post Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC10_FullRole_DoesNotHoldPostingToken()
    var
        Token: Record "Svc Posting ori";
        FullCanPost: Boolean;
        ReadCanPost: Boolean;
    begin
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        FullCanPost := Token.WritePermission();
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        ReadCanPost := Token.WritePermission();
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsFalse(FullCanPost, 'BIFROST SvcFull ori must not include the posting set.');
        Assert.IsFalse(ReadCanPost, 'BIFROST SvcRead ori must not include the posting set.');
    end;

    [Test]
    procedure Scenario_AC10_PostingSet_GrantsToken()
    var
        Token: Record "Svc Posting ori";
        CanPost: Boolean;
    begin
        LowerPermissions.SetExactPermissionSet('BIFROST SvcPost ori');
        CanPost := Token.WritePermission();
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsTrue(CanPost, 'BIFROST SvcPost ori grants the posting token.');
    end;

    [Test]
    procedure Scenario_AC10_Name_Is19Characters()
    begin
        Assert.AreEqual(19, StrLen('BIFROST SvcPost ori'), 'The permission set name is 19 characters.');
    end;

    [Test]
    procedure Scenario_AC10_WithoutToken_DirectPost_PermissionDenied()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
        Serialized: Text;
    begin
        PostData.CreateOrder(Header);
        Request := PostData.Build(Header."No.", 'true', '', 'true', 1);
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Response.WriteTo(Serialized);
        Data.AssertRefusal(Response, 'PermissionDenied');
        Assert.IsTrue(Serialized.Contains('BIFROST SvcPost ori'), 'The refusal names the permission set.');
        Assert.AreEqual(0, PostData.PostedShipments(Header."No."), 'Nothing is posted.');
    end;

    [Test]
    procedure Scenario_AC10_WithToken_PostRuns()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
        Serialized: Text;
    begin
        PostData.CreateOrder(Header);
        Request := PostData.Build(Header."No.", 'true', '', 'true', 1);
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('BIFROST SvcPost ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Response.WriteTo(Serialized);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Serialized);
    end;

    local procedure AddNativePermissions()
    begin
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
        LowerPermissions.AddPermissionSet('D365 READ');
        LowerPermissions.AddPermissionSet('D365 SALES DOC, POST');
        LowerPermissions.AddPermissionSet('D365 INV DOC, POST');
        LowerPermissions.AddPermissionSet('D365 JOURNALS, POST');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
    end;
}
