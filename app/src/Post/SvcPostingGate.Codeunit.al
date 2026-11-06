namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>
/// Posting gate for Bifrost Service Management.
/// Service.Order.Post and Service.Order.PreviewPost are listed, and Post runs, only for callers
/// holding write permission on the Svc Posting ori token (permission set BIFROST SvcPost ori).
/// </summary>
codeunit 10076078 "Svc Posting Gate ori"
{
    Access = Internal;

    /// <summary>
    /// Returns false and writes the denial on Argument when the caller cannot post service orders.
    /// </summary>
    /// <param name="Argument">The message argument. Receives the error response on denial.</param>
    /// <returns>True when the caller holds BIFROST SvcPost ori.</returns>
    internal procedure AssertCanPost(var Argument: Record "Message Argument ori"): Boolean
    var
        PostingDeniedErr: Label 'Posting denied: missing ''%1'' permission set.', Comment = '%1 = permission set name, is-IS=Bókun hafnað: vantar heimildasettið ''%1''.';
        PermissionSetNameTok: Label 'BIFROST SvcPost ori', Locked = true;
        PostingDeniedNextStepLbl: Label 'Ask an administrator to assign the %1 permission set.', Comment = '%1 = permission set name, is-IS=Biddu stjórnanda um að úthluta heimildasettinu %1.';
    begin
        if HasPostingPermission() then
            exit(true);
        Argument.RespondWithError(
            "Bifrost Error Code ori"::PermissionDenied,
            StrSubstNo(PostingDeniedErr, PermissionSetNameTok),
            '', '', '', StrSubstNo(PostingDeniedNextStepLbl, PermissionSetNameTok));
        exit(false);
    end;

    /// <summary>True when the current user has write permission on the service posting token.</summary>
    /// <returns>True when BIFROST SvcPost ori is assigned.</returns>
    internal procedure HasPostingPermission(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(Database::"Svc Posting ori");
        exit(RecRef.WritePermission());
    end;
}
