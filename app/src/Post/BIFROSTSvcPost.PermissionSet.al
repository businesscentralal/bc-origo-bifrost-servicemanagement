namespace Origo.Bifrost.ServiceManagement;

/// <summary>
/// Grants Bifrost Service Management posting.
/// Assign explicitly. Not included in BIFROST SvcFull ori or BIFROST SvcRead ori.
/// Posting runs under the caller's own Business Central permissions on the posted documents and ledgers.
/// </summary>
permissionset 10076076 "BIFROST SvcPost ori"
{
    Assignable = true;
    Caption = 'Service Posting Gate', MaxLength = 30, Comment = 'is-IS=Bókunarhlið þjónustu';

    Permissions =
        tabledata "Svc Posting ori" = RIMD;
}
