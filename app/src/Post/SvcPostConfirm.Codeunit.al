namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Counts the single service order selected before an irreversible posting.</summary>
codeunit 10076085 "Svc Post Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Returns one selected order and a localized description of the chosen posting options.</summary>
    /// <param name="Argument">Validated request, or a structured lookup refusal.</param>
    /// <param name="Count">One when the order exists.</param>
    /// <param name="Summary">Localized confirmation summary.</param>
    /// <returns>True when the order is available.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Header: Record "Service Header";
        Lookup: Codeunit "Svc Document Lookup ori";
        Options: Codeunit "Svc Post Options ori";
        Ship: Boolean;
        Consume: Boolean;
        Invoice: Boolean;
        AnySent: Boolean;
        SummaryLbl: Label 'service order %1 (%2)', Comment = '%1 = order number, %2 = posting options, is-IS=þjónustupöntun %1 (%2)';
    begin
        Count := 0;
        Summary := '';
        if not Lookup.FindDocument(Argument, "Service Document Type"::Order, Header) then
            exit(false);
        Options.ReadFlags(Argument, Ship, Consume, Invoice, AnySent);
        if not AnySent then begin
            Ship := true;
            Invoice := true;
        end;
        Count := 1;
        Summary := StrSubstNo(SummaryLbl, Header."No.", Options.OptionName(Ship, Consume, Invoice));
        exit(true);
    end;
}
