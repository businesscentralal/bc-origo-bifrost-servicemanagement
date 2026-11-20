namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Posts standalone invoices and credit memos using native posting.</summary>
codeunit 10076094 "Svc Doc Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks access and catches posting errors at the transaction boundary.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Doc Post Proc ori";
        Gate: Codeunit "Svc Posting Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        NextLbl: Label 'Correct the document or setup reported by Business Central and retry.', Comment = 'is-IS=Leiðréttu skjalið eða uppsetninguna sem Business Central nefnir og reyndu aftur.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Document.Post');
        if not Gate.AssertCanPost(Argument) then
            exit;
        Argument.SetErrorContext('no', '', NextLbl);
        ClearLastError();
        if Argument."Omit Commit" then
            Processor.Run(Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Doc Post Proc ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
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
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Posts a service invoice or credit memo. Send expectedCount 1 to confirm the document.', Comment = 'is-IS=Bókar þjónustureikning eða kreditreikning. Sendu expectedCount 1 til að staðfesta skjalið.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post service invoice, post credit memo, billing', Comment = 'is-IS=bóka þjónustureikning, bóka kreditreikning, reikningsfærsla';
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
        Contract.GetEnvelope(Envelope, 'Post');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetTarget(Target, 'Post');
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
        Contract.GetResponse(Response, 'Post');
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetErrors(Errors, 'Post');
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetEffect(Effect, 'Post');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetRelated(Related, 'Post');
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetWorkflow(Workflow, 'Post');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetExamples(Examples, 'Post');
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetNotes(Notes, 'Post');
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetOverview(Overview, 'Post');
        exit(true);
    end;

    /// <summary>Uses the default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
}
