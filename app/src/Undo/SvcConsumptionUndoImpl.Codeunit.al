namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.History;
using Origo.Bifrost;

/// <summary>Implements Service.Consumption.Undo through the standard Business Central undo.</summary>
codeunit 10076090 "Svc Consumption Undo Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Validates access and catches native undo errors outside the posting transaction.</summary>
    /// <param name="Argument">The message argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Undo Proc ori";
    begin
        Processor.Dispatch(Argument);
    end;

    /// <summary>Lists the type only for callers holding the posting token and write permission on service lines.</summary>
    /// <returns>True when listed.</returns>
    procedure IsEnabled(): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        exit(Contract.IsEnabled());
    end;

    /// <summary>Returns the posted service shipment filter scope.</summary>
    /// <returns>The table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Shipment Header");
    end;

    /// <summary>Returns the inbound direction.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    /// <returns>The description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Undoes the consumption on posted service shipment lines that were not invoiced: posts correcting entries and puts the consumed quantity back on the service order. Commits and cannot be undone.', Comment = 'is-IS=Afturkallar notkun á bókuðum þjónustuafhendingarlínum sem hafa ekki verið reikningsfærðar: bókar leiðréttingarfærslur og setur notaða magnið aftur á þjónustupöntunina. Framkvæmir Commit og ekki er hægt að afturkalla.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    /// <returns>Comma-separated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'undo service consumption, undo consumption line, reverse service consumption, correct consumed quantity', Comment = 'is-IS=afturkalla þjónustunotkun, afturkalla notkunarlínu, bakfæra þjónustunotkun, leiðrétta notað magn';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized selection guidance.</summary>
    /// <returns>The description.</returns>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    /// <param name="Envelope">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetEnvelope(Envelope);
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    /// <param name="Target">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetTarget(Target);
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    /// <param name="Parameters">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetParameters(Parameters, true);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    /// <param name="Response">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetResponse(Response, true);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    /// <param name="Errors">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetErrors(Errors, true);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    /// <param name="Effect">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetEffect(Effect, true);
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    /// <param name="Related">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetRelated(Related, true);
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    /// <param name="Workflow">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    /// <param name="Examples">The chapter.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Contract.GetExamples(Examples, true);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    /// <param name="Metering">Unused.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains commit behaviour and retry semantics.</summary>
    /// <param name="Notes">The notes.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Svc Undo Contract ori";
    begin
        Notes := Contract.GetNotes(true);
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">The overview.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Undoes the consumption on lines of a posted service shipment that were not invoiced, with the standard Business Central undo: correcting item, resource and service ledger entries are posted, correction lines are added to the shipment and the consumed quantity returns to the service order line. Send expectedCount 1. This call commits unless Omit Commit is requested.';
        exit(true);
    end;
}
