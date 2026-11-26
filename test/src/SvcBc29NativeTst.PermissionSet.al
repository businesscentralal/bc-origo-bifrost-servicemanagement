namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.CRM.Interaction;
using Microsoft.Warehouse.Request;

/// <summary>Test-only native grants that D365PREM SMG, EDIT lacks on BC 29 for release and quote conversion (#51).</summary>
permissionset 97794 "Svc BC29 Gap Tst ori"
{
    Assignable = true;
    Caption = 'Service BC 29 native test', Locked = true;
    Permissions = tabledata "Interaction Log Entry" = i,
        tabledata "Warehouse Request" = R;
}
