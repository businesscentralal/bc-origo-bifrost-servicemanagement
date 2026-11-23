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
        codeunit "Svc Post Confirm ori" = X,
        codeunit "Svc Post Options ori" = X,
        codeunit "Svc Post Contract ori" = X,
        codeunit "Svc Post Restrict ori" = X,
        codeunit "Svc Posting Gate ori" = X,
        codeunit "Svc Order Post Impl ori" = X,
        codeunit "Svc Order Post Proc ori" = X,
        codeunit "Svc Order Preview Impl ori" = X,
        codeunit "Svc Order Preview Proc ori" = X,
        codeunit "Svc Shipment Undo Impl ori" = X,
        codeunit "Svc Consumption Undo Impl ori" = X,
        codeunit "Svc Undo Proc ori" = X,
        codeunit "Svc Undo Lines ori" = X,
        codeunit "Svc Undo Confirm ori" = X,
        codeunit "Svc Undo Contract ori" = X,
        codeunit "Svc Fault Resol Suggest ori" = X,
        codeunit "Svc Write Check ori" = X,
        codeunit "Svc Resource Suggest Impl ori" = X,
        codeunit "Svc Resource Suggest ori" = X,
        table "Svc Write Gate ori" = X,
        tabledata "Svc Write Gate ori" = RIMD,
        codeunit "Svc Doc Post Impl ori" = X,
        codeunit "Svc Doc Post Proc ori" = X,
        codeunit "Svc Doc Preview Impl ori" = X,
        codeunit "Svc Doc Preview Proc ori" = X,
        codeunit "Svc Doc Confirm ori" = X,
        codeunit "Svc Doc Request ori" = X,
        codeunit "Svc Doc Contract ori" = X,
        codeunit "Svc Inv Shipment Impl ori" = X,
        codeunit "Svc Inv Shipment Proc ori" = X,
        codeunit "Svc Price Adjust Impl ori" = X,
        codeunit "Svc Price Adjust Proc ori" = X,
        codeunit "Svc Loaner Receive Impl ori" = X,
        codeunit "Svc Loaner Receive Proc ori" = X,
        codeunit "Svc Loaner Lend Impl ori" = X,
        codeunit "Svc Loaner Lend Proc ori" = X,
        codeunit "Svc Loaner Restrict ori" = X,
        codeunit "Svc Contract Make Impl ori" = X,
        codeunit "Svc Contract Sign Impl ori" = X,
        codeunit "Svc Contract Lock Impl ori" = X,
        codeunit "Svc Contract Unlock Impl ori" = X,
        codeunit "Svc Contract Proc ori" = X,
        codeunit "Svc Contract Request ori" = X,
        codeunit "Svc Contract Options ori" = X,
        codeunit "Svc Contract Restrict ori" = X,
        codeunit "Svc Contract Help ori" = X;
}
