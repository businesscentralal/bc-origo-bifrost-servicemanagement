namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost read-only permission set with the Service Management registration codeunit.
/// Service Management message types that write or run inside a transaction are not granted here on
/// purpose: a read-only Bifrost user is not meant to invoke them. Invoking one requires
/// "BIFROST Svc ori" or "BIFROST SvcFull ori". Standard D365 sets grant codeunit Execute broadly,
/// so the write types check write access to "Svc Write Gate ori", which this extension grants as read only.
/// </summary>
permissionsetextension 10076038 "BIFROST SvcRead ori" extends "BIFROST Read ori"
{
    Permissions =
        codeunit "Svc Registration ori" = X,
        codeunit "Svc Write Check ori" = X,
        table "Svc Write Gate ori" = X,
        tabledata "Svc Write Gate ori" = R;
}
