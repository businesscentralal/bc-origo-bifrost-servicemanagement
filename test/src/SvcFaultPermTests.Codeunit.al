namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves the read role can ask for fault resolution suggestions without SUPER and a user without service read access is refused.</summary>
codeunit 97791 "Svc Fault Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";
        Suggest: Codeunit "Svc Fault Suggest Tests ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC05_ReadRole_Succeeds()
    var
        Request: JsonObject;
        Response: JsonObject;
        FaultCode: Code[10];
        Serialized: Text;
    begin
        // [GIVEN] A self-made relationship row
        Suggest.SetLevel(1);
        FaultCode := Suggest.NewCode();
        Suggest.InsertRelationship(FaultCode, '', '', Suggest.NewCode(), 4, '', false);
        Request.Add('faultCode', FaultCode);
        Commit();

        // [WHEN] A Bifröst read-role user without SUPER, with read-only Business Central access, asks for suggestions
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365 READ');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();

        // [THEN] The read succeeds
        Response.WriteTo(Serialized);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Read role reads suggestions: ' + CopyStr(Serialized, 1, 900));
    end;

    [Test]
    procedure Scenario_AC05_NoServiceReadAccess_PermissionDenied()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] Fault reporting on
        Suggest.SetLevel(1);
        Request.Add('faultCode', Suggest.NewCode());
        Commit();

        // [WHEN] A Bifröst read-role user without native service read access asks for suggestions
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();

        // [THEN] The read is refused with PermissionDenied
        Data.AssertRefusal(Response, 'PermissionDenied');
    end;
}
