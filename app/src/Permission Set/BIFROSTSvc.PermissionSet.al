namespace Origo.Bifrost.ServiceManagement;

/// <summary>
/// Grants execute permission on every object in the Bifrost Service Management extension.
/// Assign this alongside a Bifrost Core permission set to let a user or service invoke the
/// Service Management message types. The message types themselves run under the caller's own
/// permissions on the Business Central Service Management tables, so this set does not widen access
/// to service data. Add every new codeunit that a message type runs to this set.
/// Write access to "Svc Write Gate ori" is what lets a caller run the Service Management message
/// types that write; "BIFROST SvcRead ori" grants only read on it.
/// </summary>
permissionset 10076036 "BIFROST Svc ori"
{
    Caption = 'Bifrost Service Management', MaxLength = 30, Comment = 'is-IS=Bifröst - þjónustustjórnun';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "Svc Registration ori" = X,
        codeunit "Svc Contract Parts ori" = X,
        codeunit "Svc Document Lookup ori" = X,
        codeunit "Svc Order Release Impl ori" = X,
        codeunit "Svc Order Reopen Impl ori" = X,
        codeunit "Svc Release Proc ori" = X,
        codeunit "Svc Release Restrict ori" = X,
        codeunit "Svc Allocation Impl ori" = X,
        codeunit "Svc Allocation Proc ori" = X,
        codeunit "Svc Alloc Check ori" = X,
        codeunit "Svc Alloc Restrict ori" = X,
        codeunit "Svc Quote MakeOrder Impl ori" = X,
        codeunit "Svc Confirm ori" = X,
        codeunit "Svc Post Confirm ori" = X,
        codeunit "Svc Post Options ori" = X,
        codeunit "Svc Post Contract ori" = X,
        codeunit "Svc Post Restrict ori" = X,
        codeunit "Svc Posting Gate ori" = X,
        codeunit "Svc Order Post Impl ori" = X,
        codeunit "Svc Order Preview Impl ori" = X,
        codeunit "Svc Order Preview Proc ori" = X,
        codeunit "Svc Write Check ori" = X,
        table "Svc Write Gate ori" = X,
        tabledata "Svc Write Gate ori" = RIMD;
}
