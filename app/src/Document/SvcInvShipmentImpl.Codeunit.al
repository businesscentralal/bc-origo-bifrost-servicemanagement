namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Collects posted shipment lines on a service invoice.</summary>
codeunit 10076101 "Svc Inv Shipment Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Runs shipment collection in one rollback boundary.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Inv Shipment Proc ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        NextLbl: Label 'Correct the invoice or shipment reported by Business Central and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu reikninginn eða afhendinguna sem Business Central nefnir og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Invoice.GetShipmentLines');
        Argument.SetErrorContext('invoiceNo', '', NextLbl);
        ClearLastError();
        if Argument."Omit Commit" then
            Processor.Run(Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Inv Shipment Proc ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
    end;

    /// <summary>Reports whether the caller can discover this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Header: Record "Service Header";
        Gate: Record "Svc Write Gate ori";
    begin
        exit(Gate.WritePermission() and Header.WritePermission());
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
        DescriptionLbl: Label 'Adds uninvoiced service shipment lines to an open service invoice.', Comment = 'is-IS=Bætir óreikningsfærðum þjónustuafhendingarlínum við opinn þjónustureikning.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'get service shipments, combine service invoices, billing', Comment = 'is-IS=sækja þjónustuafhendingar, sameina þjónustureikninga, reikningsfærsla';
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
        Contract.GetEnvelope(Envelope, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetTarget(Target, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetShipmentParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetResponse(Response, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetErrors(Errors, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetEffect(Effect, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetRelated(Related, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetWorkflow(Workflow, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetExamples(Examples, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetNotes(Notes, 'Shipment');
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Svc Doc Contract ori";
    begin
        Contract.GetOverview(Overview, 'Shipment');
        exit(true);
    end;

    /// <summary>Uses the default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
}
