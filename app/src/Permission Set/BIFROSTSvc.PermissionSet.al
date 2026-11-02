namespace Origo.Bifrost.ServiceManagement;

/// <summary>
/// Grants execute permission on every object in the Bifrost Service Management extension.
/// Assign this alongside a Bifrost Core permission set to let a user or service invoke the
/// Service Management message types. The message types themselves run under the caller's own
/// permissions on the Business Central Service Management tables, so this set does not widen access
/// to service data. Add every new codeunit that a message type runs to this set.
/// </summary>
permissionset 10076036 "BIFROST Svc ori"
{
    Caption = 'Bifrost Service Management', MaxLength = 30, Comment = 'is-IS=Bifröst - þjónustustjórnun';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "Svc Registration ori" = X,
        codeunit "Svc Contract Parts ori" = X,
        codeunit "Svc Document Lookup ori" = X;
}
