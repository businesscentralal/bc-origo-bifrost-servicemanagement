namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Counts and locks the quote selected for an irreversible service conversion.</summary>
codeunit 10076052 "Svc Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Returns one selected quote and a localized description without changing business data.</summary>
    /// <param name="Argument">Validated request, or a structured lookup refusal.</param>
    /// <param name="Count">One when the quote exists.</param>
    /// <param name="Summary">Localized confirmation summary.</param>
    /// <returns>True when the quote is available.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Header: Record "Service Header";
        Lookup: Codeunit "Svc Document Lookup ori";
        SummaryLbl: Label 'service quote %1 to a service order', Comment = '%1 = quote number, is-IS=þjónustutilboð %1 í þjónustupöntun';
    begin
        Count := 0;
        Summary := '';
        if not Lookup.FindDocument(Argument, "Service Document Type"::Quote, Header) then
            exit(false);
        Header.LockTable();
        if not Header.Get("Service Document Type"::Quote, Header."No.") then begin
            Lookup.FindDocument(Argument, "Service Document Type"::Quote, Header);
            exit(false);
        end;
        Count := 1;
        Summary := StrSubstNo(SummaryLbl, Header."No.");
        exit(true);
    end;
}
