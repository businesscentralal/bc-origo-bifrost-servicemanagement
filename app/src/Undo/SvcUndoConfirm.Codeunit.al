namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.History;
using Origo.Bifrost;

/// <summary>Counts the one posted service shipment selected before an irreversible undo and lists the lines it would undo.</summary>
codeunit 10076092 "Svc Undo Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Returns one selected shipment and a localized summary naming the lines that would be undone.</summary>
    /// <param name="Argument">Validated request, or a structured refusal.</param>
    /// <param name="Count">One when the shipment and its lines pass validation.</param>
    /// <param name="Summary">Localized confirmation summary.</param>
    /// <returns>True when the shipment and lines are available.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Header: Record "Service Shipment Header";
        Lines: Record "Service Shipment Line";
        Undo: Codeunit "Svc Undo Lines ori";
        Gate: Codeunit "Svc Posting Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        Processor: Codeunit "Svc Undo Proc ori";
        SummaryLbl: Label 'service shipment %1, lines %2', Comment = '%1 = posted shipment number, %2 = line numbers, is-IS=þjónustuafhending %1, línur %2';
    begin
        Count := 0;
        Summary := '';
        // Permission refusals come before any line validation, also on the confirmation path.
        WriteCheck.AssertCanWrite(Processor.TypeName(Undo.IsConsumption(Argument)));
        if not Gate.AssertCanPost(Argument) then
            exit(false);
        if not Undo.Select(Argument, Undo.IsConsumption(Argument), Header, Lines) then
            exit(false);
        Count := 1;
        Summary := StrSubstNo(SummaryLbl, Header."No.", Undo.LineList(Lines));
        exit(true);
    end;
}
