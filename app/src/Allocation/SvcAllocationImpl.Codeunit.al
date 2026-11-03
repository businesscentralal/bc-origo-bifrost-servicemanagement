namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Implements Service.Allocation.Allocate through standard Business Central allocation.</summary>
codeunit 10076061 "Svc Allocation Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks Foundation licensing and version, then allocates or reallocates.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Allocation Proc ori";
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

    /// <summary>Returns the service order allocation filter scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Order Allocation");
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Allocates a resource or resource group to a service item line of a service order for a date and a number of hours, or moves the allocation to another resource.', Comment = 'is-IS=Úthlutar forða eða forðaflokki á þjónustuvörulínu þjónustupöntunar fyrir dagsetningu og fjölda klukkustunda, eða færir úthlutunina á annan forða.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'allocate resource, assign technician, reallocate', Comment = 'is-IS=úthluta forða, úthluta tæknimanni, endurúthluta';
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
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.documentNo', 'document no.', 'Service order number.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Service Header SystemId of a service order.'));
        Target.Add(Contract.TargetEntry('data.entryNo', 'integer', 'Service Order Allocation entry number.'));
        Target.Add(Contract.TargetEntry('subject', 'document no.', 'Plain service order number, as an alternative to data.documentNo.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetAllocationParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetAllocationResponse(Response);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetAllocationErrors(Errors);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetAllocationEffect(Effect);
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetAllocationRelated(Related);
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
        Parts.GetAllocationExamples(Examples);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains the zone acknowledgment and why cancellation is not offered.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Orders only. When Service Zones Option is Warning Displayed, a resource outside the order service zone is refused unless acceptOutsideServiceZone is true. With Code Shown the flag is not required. Cancelling an allocation is not supported: Business Central cancels only through a modal page, so move the allocation to another resource instead. Omit Commit keeps the caller transaction.';
        exit(true);
    end;

    /// <summary>Summarizes the resulting allocation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the active allocation entry. A Nonactive entry becomes Active. An Active or Reallocation Needed entry is moved: the previous entry is Canceled, or Finished when service had started, and the active entry carries the new resource and reason code.';
        exit(true);
    end;
}
