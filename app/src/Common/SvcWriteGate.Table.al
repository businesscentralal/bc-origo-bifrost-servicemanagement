namespace Origo.Bifrost.ServiceManagement;

/// <summary>
/// Permission gate for the Service Management message types that write.
/// No records are stored. Its WritePermission() is the check target: only "BIFROST Svc ori"
/// (and so the "BIFROST SvcFull ori" extension of "BIFROST Full ori") grants tabledata write.
/// Standard D365 permission sets grant Execute on codeunits beyond their own objects, so a missing
/// codeunit Execute grant alone does not stop a read-only Bifrost user; this gate does.
/// </summary>
table 10076065 "Svc Write Gate ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'Bifrost Service Management Write Gate', Comment = 'is-IS=Skrifhlið Bifröst þjónustustjórnunar';
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
