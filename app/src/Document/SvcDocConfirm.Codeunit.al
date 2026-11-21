namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Counts the document only after validating access and identity.</summary>
codeunit 10076098 "Svc Doc Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Returns the single invoice or credit memo selected for posting.</summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Header: Record "Service Header";
        Request: Codeunit "Svc Doc Request ori";
        Gate: Codeunit "Svc Posting Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        SummaryLbl: Label 'service document %1', Comment = '%1 = document number, is-IS=þjónustuskjal %1';
    begin
        Count := 0;
        Summary := '';
        WriteCheck.AssertCanWrite('Service.Document.Post');
        if not Gate.AssertCanPost(Argument) then
            exit(false);
        if not Request.Find(Argument, Header) then
            exit(false);
        Count := 1;
        Summary := StrSubstNo(SummaryLbl, Header."No.");
        exit(true);
    end;
}
