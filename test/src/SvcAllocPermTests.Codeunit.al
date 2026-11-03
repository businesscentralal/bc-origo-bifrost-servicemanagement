namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves the service full-role extension can allocate and the read-role extension cannot.</summary>
codeunit 97729 "Svc Alloc Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_FullRole_CanAllocate()
    var
        Header: Record "Service Header";
        Resource: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.CreateResourceFor(Header."Customer No.", Resource);
        Data.SilenceServiceRules(Zones, Skills);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', Resource."No.");
        Request.Add('allocatedHours', 1);
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Data.RestoreServiceRules(Zones, Skills);
        Commit();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role allocates.');
    end;

    [Test]
    procedure Scenario_ReadRole_CannotAllocate()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
        ErrorText: Text;
        PreviousLanguage: Integer;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', 'X');
        Request.Add('allocatedHours', 1);
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        AddNativePermissions();
        asserterror Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
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
