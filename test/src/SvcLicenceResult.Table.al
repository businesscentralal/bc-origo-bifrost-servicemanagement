namespace Origo.Bifrost.ServiceManagement.Test;

/// <summary>Holds one owned background-session result for an actual unlicensed-company test.</summary>
table 97713 "Svc Licence Result Tst ori"
{
    DataClassification = SystemMetadata;
    DataPerCompany = false;

    fields
    {
        field(1; Id; Guid) { }
        field(2; Completed; Boolean) { }
        field(3; Response; Blob) { }
    }
    keys
    {
        key(PK; Id) { Clustered = true; }
    }
}
