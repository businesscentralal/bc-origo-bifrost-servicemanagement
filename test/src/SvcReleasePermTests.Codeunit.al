namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves the Service Management full-role extension grants writes and its read-role extension does not.</summary>
codeunit 97709 "Svc Release Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC15_FullRole_ReleaseAndReopen()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // BIFROST SvcFull is a permission-set extension, so assign the actual BIFROST Full base role.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', Header."No.");
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role releases.');
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Reopen", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role reopens.');
    end;

    [Test]
    procedure Scenario_AC15_ReadRole_DeniedBothWrites()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', Header."No.");
        Commit();
        AssertReadDenied("Message Type ori"::"Service.Order.Release", Request);
        AssertReadDenied("Message Type ori"::"Service.Order.Reopen", Request);
    end;

    local procedure AssertReadDenied(MessageType: Enum "Message Type ori"; Request: JsonObject)
    var
        Response: JsonObject;
        ErrorText: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        AddNativePermissions();
        asserterror Response := Data.Invoke(MessageType, Request, '', 1033, false);
        ErrorText := GetLastErrorText();
        LowerPermissions.SetOutsideO365Scope();
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(ErrorText.Contains('permission') or ErrorText.Contains('Permission'), 'Platform must deny implementation execution.');
    end;

    local procedure AddNativePermissions()
    begin
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
    end;
}
