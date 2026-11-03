namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Runs service allocation inside the caller's transaction or an isolated rollback boundary.</summary>
codeunit 10076062 "Svc Allocation Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Check: Codeunit "Svc Alloc Check ori";
    begin
        if not Check.Load(Rec) then
            exit;
        Check.Apply(Rec);
    end;

    var
        FinishedNextLbl: Label 'Correct the finished service order or service item line and try again.', Comment = 'is-IS=Leiðréttu þjónustupöntunina eða þjónustuvörulínuna sem er lokið og reyndu aftur.';
        BcNextLbl: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu villuna frá Business Central og reyndu aftur.';

    /// <summary>Validates the request, then allocates without committing an Omit Commit transaction.</summary>
    internal procedure Execute(var Argument: Record "Message Argument ori")
    var
        Check: Codeunit "Svc Alloc Check ori";
    begin
        // Load before Codeunit.Run so the parameter-key guard sees every declared read.
        if not Check.Load(Argument) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Svc Allocation Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Allocation Proc ori", Argument) then
                HandleFailure(Argument);
    end;

    local procedure HandleFailure(var Argument: Record "Message Argument ori")
    var
        Check: Codeunit "Svc Alloc Check ori";
        Response: JsonObject;
        ErrorCode: JsonToken;
    begin
        Argument.RespondWithLastError();
        Response := Argument.GetResponseJson();
        if Response.Get('code', ErrorCode) then
            if ErrorCode.AsValue().AsText() = 'Retryable' then
                exit;
        // Foundation reports a dedicated field write as PermissionDenied. A finished order or line is a precondition.
        if Check.IsFinishedPrecondition(Argument) then begin
            if Response.Contains('code') then
                Response.Replace('code', 'PreconditionFailed')
            else
                Response.Add('code', 'PreconditionFailed');
            if Response.Contains('nextStep') then
                Response.Replace('nextStep', FinishedNextLbl)
            else
                Response.Add('nextStep', FinishedNextLbl);
        end else
            if not Response.Contains('nextStep') then
                Response.Add('nextStep', BcNextLbl);
        Argument.SetResponseJson(Response);
    end;
}
