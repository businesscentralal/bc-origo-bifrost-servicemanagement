namespace Origo.Bifrost.ServiceManagement;

/// <summary>Refuses a Service Management write message type unless the caller holds "BIFROST Svc ori" or "BIFROST Full ori".</summary>
codeunit 10076066 "Svc Write Check ori"
{
    Access = Internal;

    var
        NoWritePermissionErr: Label 'You do not have permission to run the Service Management message type %1. Ask your administrator for the BIFROST Svc ori or BIFROST Full ori permission set.', Comment = '%1 = message type name, is-IS=Þú hefur ekki heimild til að keyra þjónustustjórnunarskeytagerðina %1. Biddu kerfisstjóra um heimildasamstæðuna BIFROST Svc ori eða BIFROST Full ori.';

    /// <summary>Raises a permission error before any service data is read or changed when the caller lacks the write gate.</summary>
    /// <param name="MessageTypeName">The message type name shown in the error.</param>
    internal procedure AssertCanWrite(MessageTypeName: Text)
    var
        Gate: Record "Svc Write Gate ori";
    begin
        if not Gate.WritePermission() then
            Error(NoWritePermissionErr, MessageTypeName);
    end;
}
