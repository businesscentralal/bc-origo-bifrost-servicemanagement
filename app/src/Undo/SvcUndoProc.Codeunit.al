namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.History;
using Origo.Bifrost;

/// <summary>Validates, confirms and undoes posted service shipment or consumption lines within one error boundary.</summary>
codeunit 10076089 "Svc Undo Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteUndo(Rec);
    end;

    local procedure ExecuteUndo(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Shipment Header";
        Lines: Record "Service Shipment Line";
        Undo: Codeunit "Svc Undo Lines ori";
        Gate: Codeunit "Svc Posting Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        Response: JsonObject;
        Consumption: Boolean;
        UndoNextLbl: Label 'Correct the entries or document named by Business Central and send the undo again. Nothing was posted.', Comment = 'is-IS=Leiðréttu færslurnar eða skjalið sem Business Central nefnir og sendu afturköllunina aftur. Ekkert var bókað.';
    begin
        Consumption := Undo.IsConsumption(Argument);
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite(TypeName(Consumption));
        if not Gate.AssertCanPost(Argument) then
            exit;
        Lines.LockTable();
        if not Undo.Select(Argument, Consumption, Header, Lines) then
            exit;
        if not ConfirmGate.Check(Argument, Argument.Type) then
            exit;
        Argument.SetErrorContext('documentNo', '', UndoNextLbl);
        ClearLastError();
        Undo.UndoLines(Header, Lines, Consumption, Response);
        Argument.ClearErrorContext();
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Returns the public type name for the write check.</summary>
    /// <param name="Consumption">True for consumption undo.</param>
    /// <returns>Service.Consumption.Undo or Service.Shipment.Undo.</returns>
    internal procedure TypeName(Consumption: Boolean): Text
    begin
        if Consumption then
            exit('Service.Consumption.Undo');
        exit('Service.Shipment.Undo');
    end;

    /// <summary>Runs the undo from an Impl codeunit: directly under Omit Commit, otherwise inside a caught Codeunit.Run boundary.</summary>
    /// <param name="Argument">The message argument.</param>
    internal procedure Dispatch(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Undo Proc ori";
        Gate: Codeunit "Svc Posting Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        Undo: Codeunit "Svc Undo Lines ori";
        UndoNextLbl: Label 'Correct the entries or document named by Business Central and send the undo again. Nothing was posted.', Comment = 'is-IS=Leiðréttu færslurnar eða skjalið sem Business Central nefnir og sendu afturköllunina aftur. Ekkert var bókað.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite(TypeName(Undo.IsConsumption(Argument)));
        if not Gate.AssertCanPost(Argument) then
            exit;
        Argument.SetErrorContext('documentNo', '', UndoNextLbl);
        ClearLastError();
        if Argument."Omit Commit" then begin
            // A chained dispatcher call already has queue writes; a Boolean Codeunit.Run is illegal there.
            // The direct path keeps Business Central's own behaviour and raises errors to the caller.
            Processor.Run(Argument);
            Argument.ClearErrorContext();
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Svc Undo Proc ori", Argument) then begin
            Argument.RespondWithLastError();
            exit;
        end;
        Argument.ClearErrorContext();
    end;
}
