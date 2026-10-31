namespace Origo.Bifrost.ServiceManagement.Test;

using System.Environment.Configuration;

/// <summary>
/// Minimal platform baseline for the registration test that runs under the licence administrator
/// role. Bifrost roles do not grant Microsoft tables; this set supplies the indirect extension
/// settings read that Bifrost Setup needs. It mirrors Bifrost Foundation's own test fixture
/// "Wizard Platform ori", which lives in Foundation's test app and is not part of the published
/// Foundation app that this pipeline installs.
/// </summary>
permissionset 97703 "Svc Platform Tst ori"
{
    Assignable = true;
    Caption = 'Svc Platform Test', Locked = true;
    IncludedPermissionSets = "Guided Experience - View";
    Permissions = tabledata "NAV App Setting" = r;
}
