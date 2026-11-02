namespace Origo.Bifrost.ServiceManagement.Test;

/// <summary>Grants test infrastructure only, with no service lifecycle implementation rights.</summary>
permissionset 97710 "Svc NoGrant Tst ori"
{
    Assignable = true;
    Caption = 'Service permission test', Locked = true;
    IncludedPermissionSets = "Svc Platform Tst ori";
    Permissions = codeunit "Svc Test Data ori" = X,
                  codeunit "Svc Release Perm Tests ori" = X,
                  table "Svc Licence Result Tst ori" = X,
                  tabledata "Svc Licence Result Tst ori" = RIMD;
}
