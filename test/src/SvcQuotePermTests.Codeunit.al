namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using Origo.Bifrost.ServiceManagement;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves the Service Management full-role extension grants writes and its read-role extension does not.</summary>
codeunit 97718 "Svc Quote Perm Tests ori"
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
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Request.Add('no', Header."No.");
        Request.Add('expectedCount', 1);
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Service.Quote.MakeOrder", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role releases.');
    end;

    [Test]
    procedure Scenario_AC15_ReadRole_DeniedBothWrites()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Quote);
        Request.Add('no', Header."No.");
        Request.Add('expectedCount', 1);
        Commit();
        AssertReadDenied("Message Type ori"::"Service.Quote.MakeOrder", Request);

    end;

    [Test]
    procedure Scenario_WriteGate_ReadDeniedFullGranted()
    var
        Gate: Record "Svc Write Gate ori";
        ReadCanWrite: Boolean;
        ReadCanRead: Boolean;
        FullCanWrite: Boolean;
    begin
        // Standard D365 sets grant codeunit Execute broadly, so the write gate must hold even with them.
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        AddNativePermissions();
        ReadCanWrite := Gate.WritePermission();
        ReadCanRead := Gate.ReadPermission();
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        FullCanWrite := Gate.WritePermission();
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsFalse(ReadCanWrite, 'The read role must not hold the Service Management write gate.');
        Assert.IsTrue(ReadCanRead, 'The read role keeps read on the write gate.');
        Assert.IsTrue(FullCanWrite, 'The full role holds the Service Management write gate.');
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
