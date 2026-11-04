namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Implements Service.Order.PreviewPost through Business Central's posting preview.</summary>
codeunit 10076081 "Svc Order Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        Lookup: Codeunit "Svc Document Lookup ori";
        Options: Codeunit "Svc Post Options ori";
        Proc: Codeunit "Svc Order Preview Proc ori";
        PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler";
        PostingPreviewHelper: Codeunit "Posting Preview Helper ori";
        Response: JsonObject;
        TotalsJson: JsonObject;
        PreviewArray: JsonArray;
        PreviewFieldNames: List of [Text];
        Ship: Boolean;
        Consume: Boolean;
        Invoice: Boolean;
        AnySent: Boolean;
        Balanced: Boolean;
        EntryCount: Integer;
        GLEntryCount: Integer;
        PreviewErrorText: Text;
        OmitCommitErr: Label 'Preview needs its own transaction and cannot run under Omit Commit.', Comment = 'is-IS=Forskoðun þarf eigin færslu og getur ekki keyrt undir Omit Commit.';
        OmitCommitNextLbl: Label 'Run the preview without Omit Commit.', Comment = 'is-IS=Keyrðu forskoðunina án Omit Commit.';
        PreviewFailedErr: Label 'Posting preview failed and no entries were captured. The order cannot be posted in its current state.', Comment = 'is-IS=Bókunarforskoðun mistókst og engar færslur voru teknar. Ekki er hægt að bóka pöntunina í núverandi stöðu.';
        NothingToPostNextLbl: Label 'Set Qty. to Ship, Qty. to Consume or Qty. to Invoice on the lines with Data.Records.Set.', Comment = 'is-IS=Settu Qty. to Ship, Qty. to Consume eða Qty. to Invoice á línurnar með Data.Records.Set.';
        SummaryLbl: Label 'Preview-posting service order %1 (%2) would create %3 ledger entries across %4 tables. %5', Comment = '%1 = order number, %2 = options, %3 = entries, %4 = tables, %5 = G/L status, is-IS=Forskoðun bókunar þjónustupöntunar %1 (%2) myndi búa til %3 færslur í %4 töflum. %5';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, OmitCommitErr, '', '', '', OmitCommitNextLbl);
            exit;
        end;
        Options.ReadFlags(Argument, Ship, Consume, Invoice, AnySent);
        if not Lookup.FindDocument(Argument, "Service Document Type"::Order, Header) then
            exit;
        if Options.RespondBadFlags(Argument) then
            exit;
        if not Options.Resolve(Argument, Ship, Consume, Invoice, AnySent) then
            exit;
        if not Options.CheckSomethingToPost(Argument, Header, Ship, Consume, Invoice) then
            exit;
        if not Proc.Preview(Header, Ship, Consume, Invoice, PostingPreviewEventHandler, PreviewErrorText) then begin
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

    /// <summary>Listed only for callers holding the posting token, as Foundation lists its preview types.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Svc Posting Gate ori";
    begin
        exit(Gate.HasPostingPermission());
    end;

    /// <summary>Returns the service header filter scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Header");
    end;

    /// <summary>Both: a preview of a write takes the same request.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Both);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Shows the entries that posting a service order would create. Changes nothing.', Comment = 'is-IS=Sýnir færslurnar sem bókun þjónustupöntunar myndi búa til. Breytir engu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview service order posting, simulate posting, what would post, check before invoicing a service order', Comment = 'is-IS=forskoða bókun þjónustupöntunar, herma bókun, hvað myndi bókast, athuga áður en þjónustupöntun er reikningsfærð';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetEnvelope(Envelope);
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetTarget(Target);
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Name: Text;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        foreach Name in 'entryCount,glEntryCount'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'integer', 'Captured entries across every preview table, and the G/L entries among them.'));
        Fields.Add(Contract.ResponseField('rollback', 'boolean', 'Always true: nothing was posted.'));
        foreach Name in 'summary,documentNo'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'string', 'One-sentence summary and the previewed order.'));
        foreach Name in 'ship,consume,invoice'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'boolean', 'The options previewed.'));
        Fields.Add(Contract.ResponseField('totals', 'object', 'G/L totals over the captured entries.'));
        Fields.Add(Contract.ResponseField('preview', 'array', 'One element per ledger table the preview filled, in the Data.Records.Get entry shape.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetErrors(Errors, true);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing: the preview runs through Business Central''s posting preview and the transaction is rolled back. No entry, posted document or number-series use remains.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST SvcPost ori');
        Effect.Add('preconditions', 'Quantities on the lines for the chosen options.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetRelated(Related, true);
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Preview ship and invoice', '{"type":"Service.Order.PreviewPost","data":{"no":"SVC-ORDER1"}}', '{"status":"Success","entryCount":6,"glEntryCount":3,"rollback":true,"documentNo":"SVC-ORDER1","ship":true,"consume":false,"invoice":true}'));
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains the preview boundary.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The type is listed only for callers holding BIFROST SvcPost ori but runs no posting gate itself. In a preview Business Central writes the placeholder *** as every Document No. Under Omit Commit the preview is refused because it needs its own transaction.';
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Simulates posting a service order and returns every ledger entry the posting would create, then rolls back. Use it before Service.Order.Post; nothing is changed.';
        exit(true);
    end;
}
