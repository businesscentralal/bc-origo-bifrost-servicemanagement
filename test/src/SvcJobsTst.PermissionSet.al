namespace Origo.Bifrost.ServiceManagement.Test;

using System.Security.AccessControl;

/// <summary>Supplies native service document editing rights for contract job permission tests.</summary>
permissionset 97793 "Svc Jobs Tst ori"
{
    Assignable = true;
    Caption = 'Service document job test', Locked = true;
    IncludedPermissionSets = "Service Documents - Edit";
}
