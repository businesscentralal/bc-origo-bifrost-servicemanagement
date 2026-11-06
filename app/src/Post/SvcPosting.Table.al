namespace Origo.Bifrost.ServiceManagement;

/// <summary>
/// Permission token for BIFROST SvcPost ori.
/// No records are stored. WritePermission() on this table is the service order posting gate.
/// </summary>
table 10076075 "Svc Posting ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'BIFROST SvcPost ori', Comment = 'is-IS=Bifröst bókun þjónustu';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
