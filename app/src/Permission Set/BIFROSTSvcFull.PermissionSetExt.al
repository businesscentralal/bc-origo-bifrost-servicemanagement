namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost full access permission set with the Service Management objects,
/// so anyone already granted full Bifrost access can invoke these message types too.
/// The extension includes "BIFROST Svc ori" instead of repeating its list, so the two always
/// grant the same objects; add a new object to "BIFROST Svc ori" only.
/// The message types still run under the caller's own permissions on the Service Management tables,
/// so this does not widen access to service data.
/// </summary>
permissionsetextension 10076037 "BIFROST SvcFull ori" extends "BIFROST Full ori"
{
    IncludedPermissionSets = "BIFROST Svc ori";
}
