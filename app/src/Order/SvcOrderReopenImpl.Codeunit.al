namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Implements Service.Order.Reopen through the standard Business Central service lifecycle.</summary>
codeunit 10076043 "Svc Order Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks Foundation licensing and version before invoking the service operation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Release Proc ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Processor.Execute(Argument);
    end;

    /// <summary>Enables discovery without reading application tables.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the service header filter scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Header");
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reopens a released service order so it can be changed again.', Comment = 'is-IS=Enduropnar útgefna þjónustupöntun svo hægt sé að breyta henni aftur.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reopen service order, change released order', Comment = 'is-IS=enduropna þjónustupöntun, breyta útgefinni pöntun';
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
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetIdentityParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetReleaseResponse(Response);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetReleaseErrors(Errors);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetReleaseEffect(Effect);
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetReleaseRelated(Related);
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetServiceWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetReleaseExamples(Examples);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains the order-only scope and transaction semantics.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Only service orders are supported. Repeating an operation in its target state is refused. Omit Commit keeps the caller transaction. This changes Release Status, not the separate service Status.';
        exit(true);
    end;

    /// <summary>Summarizes the resulting service order state.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the service order identity, release status before and after the standard BC operation, and recalculated amounts.';
        exit(true);
    end;
}
