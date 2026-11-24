namespace Origo.Bifrost.ServiceManagement.Test;

using System.Security.AccessControl;

/// <summary>Provides native contract rights without relying on a tenant-created legacy role.</summary>
permissionset 97779 "Svc Contract Tst ori"
{
    Assignable = true;
    Caption = 'Service contract test', Locked = true;
    IncludedPermissionSets = "Service Contract - Edit";
}
