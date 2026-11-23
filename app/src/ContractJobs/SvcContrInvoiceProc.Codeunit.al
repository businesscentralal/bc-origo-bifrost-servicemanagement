namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Isolates CreateInvoices writes and preserves the caller's transaction boundary.</summary>
codeunit 10076163 "Svc Contr Invoice Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Jobs: Codeunit "Svc Contr Jobs ori";
    begin
        Jobs.Run(Rec);
    end;

    /// <summary>Validates the entire scope before entering the isolated write boundary.</summary>
    internal procedure Execute(var Argument: Record "Message Argument ori")
    var
        Scope: Codeunit "Svc Contr Job Scope ori";
        Contracts: List of [Code[20]];
        FromDate: Date;
        ToDate: Date;
        CorrectLbl: Label 'Correct the field or setup named by Business Central and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu reitinn eða uppsetninguna sem Business Central nefnir og reyndu aftur. Engu var breytt.';
    begin
        if not Scope.Resolve(Argument, Contracts, FromDate, ToDate, false) then
            exit;
        Argument.SetErrorContext('', '', CorrectLbl);
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Svc Contr Invoice Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Contr Invoice Proc ori", Argument) then
                Argument.RespondWithLastError();
        Argument.ClearErrorContext();
    end;
}
