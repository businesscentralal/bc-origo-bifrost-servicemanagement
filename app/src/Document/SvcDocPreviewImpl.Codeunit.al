namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Implements Service.Document.PreviewPost through Business Central's posting preview.</summary>
codeunit 10076096 "Svc Doc Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Previews the posting; nothing is posted, no number is used and the transaction is rolled back.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        TempDocumentEntry: Record "Document Entry" temporary;
        Lookup: Codeunit "Svc Doc Request ori";
        Gate: Codeunit "Svc Posting Gate ori";
        Options: Codeunit "Svc Post Options ori";
        Proc: Codeunit "Svc Doc Preview Proc ori";
        PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler";
        PostingPreviewHelper: Codeunit "Posting Preview Helper ori";
        Response: JsonObject;
        TotalsJson: JsonObject;
        PreviewArray: JsonArray;
        PreviewFieldNames: List of [Text];
        Ship: Boolean;
        Consume: Boolean;
        Invoice: Boolean;
        Balanced: Boolean;
        EntryCount: Integer;
        GLEntryCount: Integer;
        PreviewErrorText: Text;
        OmitCommitErr: Label 'Preview needs its own transaction and cannot run under Omit Commit.', Comment = 'is-IS=Forskoðun þarf eigin færslu og getur ekki keyrt undir Omit Commit.';
        OmitCommitNextLbl: Label 'Run the preview without Omit Commit.', Comment = 'is-IS=Keyrðu forskoðunina án Omit Commit.';
        PreviewFailedErr: Label 'Posting preview failed and no entries were captured. The document cannot be posted in its current state.', Comment = 'is-IS=Bókunarforskoðun mistókst og engar færslur voru teknar. Ekki er hægt að bóka skjalið í núverandi stöðu.';
        NothingToPostNextLbl: Label 'Set Qty. to Ship, Qty. to Consume or Qty. to Invoice on the lines with Data.Records.Set.', Comment = 'is-IS=Settu Qty. to Ship, Qty. to Consume eða Qty. to Invoice á línurnar með Data.Records.Set.';
        SummaryLbl: Label 'Preview-posting service document %1 (%2) would create %3 ledger entries across %4 tables. %5', Comment = '%1 = order number, %2 = options, %3 = entries, %4 = tables, %5 = G/L status, is-IS=Forskoðun bókunar þjónustuskjals %1 (%2) myndi búa til %3 færslur í %4 töflum. %5';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, OmitCommitErr, '', '', '', OmitCommitNextLbl);
            exit;
        end;
        if not Gate.AssertCanPost(Argument) then
            exit;
        if not Lookup.Find(Argument, Header) then
            exit;
        Ship := Header."Document Type" = Header."Document Type"::Invoice;
        Invoice := true;
        if not Proc.Preview(Header, PostingPreviewEventHandler, PreviewErrorText) then begin
            if PreviewErrorText = '' then
                PreviewErrorText := PreviewFailedErr;
            PostingPreviewHelper.RespondWithPreviewError(Argument, PreviewErrorText, NothingToPostNextLbl);
            exit;
        end;
        PostingPreviewHelper.GetPreviewFieldNames(PreviewFieldNames);
        PostingPreviewEventHandler.FillDocumentEntry(TempDocumentEntry);
        if TempDocumentEntry.FindSet() then
            repeat
                PostingPreviewHelper.AddTableToPreview(PreviewArray, PostingPreviewEventHandler, TempDocumentEntry."Table ID", TempDocumentEntry."Table Name", PreviewFieldNames);
            until TempDocumentEntry.Next() = 0;
        if not PostingPreviewHelper.EvaluatePreviewOutcome(Argument, PreviewArray, PostingPreviewEventHandler, NothingToPostNextLbl, TotalsJson, Balanced, EntryCount, GLEntryCount) then
            exit;
        Response.Add('status', 'Success');
        PostingPreviewHelper.AddEntryCounts(Response, EntryCount, GLEntryCount);
        Response.Add('rollback', true);
        Response.Add('summary', StrSubstNo(SummaryLbl, Header."No.", Options.OptionName(Ship, Consume, Invoice), EntryCount, PreviewArray.Count(), PostingPreviewHelper.GLStatusSentence(GLEntryCount, Balanced)));
        Response.Add('documentNo', Header."No.");
        Response.Add('ship', Ship);
        Response.Add('consume', Consume);
        Response.Add('invoice', Invoice);
        Response.Add('totals', TotalsJson);
        Response.Add('preview', PreviewArray);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Reports whether the caller can discover this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Svc Posting Gate ori";
    begin
        exit(Gate.HasPostingPermission());
    end;

    /// <summary>Returns the service document scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Header");
    end;

    /// <summary>Returns the operation direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Previews a service invoice or credit memo and rolls back every entry.', Comment = 'is-IS=Forskoðar þjónustureikning eða kreditreikning og bakfærir allar færslur.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview service invoice, preview credit memo, entries', Comment = 'is-IS=forskoða þjónustureikning, forskoða kreditreikning, færslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetEnvelope(Envelope, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetTarget(Target, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetDocumentParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetResponse(Response, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetErrors(Errors, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetEffect(Effect, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetRelated(Related, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetWorkflow(Workflow, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetExamples(Examples, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetNotes(Notes, 'Preview');
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetOverview(Overview, 'Preview');
        exit(true);
    end;

    /// <summary>Uses the default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
}
