namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Implements Service.Resource.Suggest: a read that ranks resources for a service item line.</summary>
codeunit 10076131 "Svc Resource Suggest Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks Foundation licensing and version, then ranks the resources. Nothing is written.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Suggest: Codeunit "Svc Resource Suggest ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Suggest.Execute(Argument);
    end;

    /// <summary>Enables discovery without reading application tables.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the service item line scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Item Line");
    end;

    /// <summary>Returns the outbound direction of a read.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Lists the resources that are qualified, work in the service zone and have free hours for a service item line of a service order, best match first.', Comment = 'is-IS=Birtir forða sem hafa hæfni, vinna á þjónustusvæðinu og eiga lausar klukkustundir fyrir þjónustuvörulínu þjónustupöntunar, bestu samsvörun fyrst.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'suggest resource, qualified technician, available resource, dispatch', Comment = 'is-IS=stinga upp á forða, hæfur tæknimaður, laus forði, útdeiling verka';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Returns the envelope contract chapter. A plain subject is not used.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.documentNo', 'document no.', 'Service order number. Send it with data.serviceItemLineNo.'));
        Target.Add(Contract.TargetEntry('data.serviceItemLineNo', 'integer', 'Line No. of the service item line on the order.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Service Item Line SystemId, as an alternative to documentNo and serviceItemLineNo.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Service order number, at most 20 characters. Required with serviceItemLineNo unless systemId is sent.'));
        Parameters.Add(Contract.Parameter('serviceItemLineNo', 'integer', false, 'Line No. of the service item line. Required with documentNo.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Service Item Line SystemId. Every supplied identifier must identify the same line.'));
        Parameters.Add(Contract.Parameter('dateFrom', 'string', false, 'First day of the period as yyyy-mm-dd. Defaults to the work date.'));
        Parameters.Add(Contract.Parameter('dateTo', 'string', false, 'Last day of the period as yyyy-mm-dd. Defaults to dateFrom. The period is at most 31 days.'));
        Parameters.Add(Contract.Parameter('resourceGroupNo', 'string', false, 'Only resources in this resource group.'));
        Parameters.Add(Contract.Parameter('includeUnqualified', 'boolean', false, 'Also return resources without the required skills. Default is false.'));
        Parameters.Add(Contract.Parameter('top', 'integer', false, 'Maximum number of resources returned, 1 to 100. Default is 20.'));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'Service order number.'));
        Fields.Add(Contract.ResponseField('serviceItemLineNo', 'integer', 'Service item line the resources were ranked for.'));
        Fields.Add(Contract.ResponseField('serviceZoneCode', 'string', 'Service zone of the order. Empty when the order has none.'));
        Fields.Add(Contract.ResponseField('dateFrom', 'string', 'First day of the period as yyyy-mm-dd.'));
        Fields.Add(Contract.ResponseField('dateTo', 'string', 'Last day of the period as yyyy-mm-dd.'));
        Fields.Add(Contract.ResponseField('skillsApplied', 'boolean', 'False when the service setup does not use resource skills. qualified is then null.'));
        Fields.Add(Contract.ResponseField('zonesApplied', 'boolean', 'False when the service setup does not use service zones or the order has no zone. inServiceZone is then null.'));
        Fields.Add(Contract.ResponseField('count', 'integer', 'Number of resources returned.'));
        Fields.Add(Contract.ResponseField('resources', 'array', 'Ranked resources: qualified first, then in the service zone, then most available hours, then resource no.'));
        Fields.Add(Contract.ResponseField('resources[].resourceNo', 'string', 'Resource no.'));
        Fields.Add(Contract.ResponseField('resources[].name', 'string', 'Resource name.'));
        Fields.Add(Contract.ResponseField('resources[].resourceGroupNo', 'string', 'Resource group of the resource.'));
        Fields.Add(Contract.ResponseField('resources[].qualified', 'boolean', 'True when the resource has every skill the service item, item or service item group requires. Null when skills are not applied.'));
        Fields.Add(Contract.ResponseField('resources[].inServiceZone', 'boolean', 'True when the resource works in the order service zone. Null when zones are not applied.'));
        Fields.Add(Contract.ResponseField('resources[].capacity', 'number', 'Capacity hours in the period.'));
        Fields.Add(Contract.ResponseField('resources[].allocatedHours', 'number', 'Hours in active, unposted service order allocations in the period.'));
        Fields.Add(Contract.ResponseField('resources[].availableHours', 'number', 'capacity minus allocatedHours. Can be negative when the resource is overbooked.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No service item line was identified.', 'Send documentNo with serviceItemLineNo, or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value is empty, too long, out of range, or the line is not on a service order.', 'Correct the named parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value is not the documented JSON type or format, the period is longer than 31 days, or dateTo is before dateFrom.', 'Use a string, integer, boolean or yyyy-mm-dd as documented, with a period of at most 31 days.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The service item line or resource group was not found.', 'Read Service Item Line or Resource Group with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'systemId and documentNo or serviceItemLineNo name different lines.', 'Send identifiers belonging to the same service item line.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read service item lines, resources, skills, zones, capacity or allocations.', 'Ask an administrator for read access to service management and resources.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several declared parameters are invalid.', 'Correct each returned parameter error.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request carries a key that is not declared.', 'Remove the undeclared parameter.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter: a read.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads the service item line, resources, skills, service zones, capacity and service order allocations.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('A service item line on a service order.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Service.Allocation.Allocate', 'Allocate the chosen resource to the service item line.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Dispatch board: read Service Header with Document Type Order, sorted by Status, Response Date, Response Time and Priority, with No. of Allocations and Reallocation Needed.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Data.Records.Get', 'Find the orders waiting for allocation on the dispatch board (Service Header, Reallocation Needed or No. of Allocations = 0).'));
        Steps.Add(Contract.WorkflowStep('Service.Resource.Suggest', 'Rank the resources for one service item line.'));
        Steps.Add(Contract.WorkflowStep('Service.Allocation.Allocate', 'Allocate the chosen resource.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('description', 'Dispatching: read the waiting orders, rank resources for a line, then allocate the chosen one.');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Data: JsonObject;
    begin
        Data.Add('documentNo', 'SO000001');
        Data.Add('serviceItemLineNo', 10000);
        Data.Add('dateFrom', '2026-11-23');
        Data.Add('dateTo', '2026-11-27');
        Data.Add('top', 5);
        Example.Add('description', 'Rank the five best resources for line 10000 in a working week.');
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains how the service setup options change the ranking.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Orders only. Skills follow the service setup: when Resource Skills Option is Not Used, every resource is returned and qualified is null. A resource is qualified when it has every skill of the service item; without a service item, of the item; otherwise of the service item group. Zones follow Service Zones Option: when Not Used, or when the order has no service zone, inServiceZone is null and the ranking ignores zones. Resources outside the zone are ranked lower, not removed. Blocked resources are left out. Nothing is written.';
        exit(true);
    end;

    /// <summary>Summarizes the ranking.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Ranks resources for one service item line: qualified first, then in the service zone, then most available hours in the period. Available hours are capacity minus active, unposted service order allocations. Pick one and call Service.Allocation.Allocate.';
        exit(true);
    end;
}
