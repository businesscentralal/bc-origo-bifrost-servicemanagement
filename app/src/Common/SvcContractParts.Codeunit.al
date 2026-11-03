namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Shared identity and validation contract chapters for the service document lifecycle.</summary>
codeunit 10076040 "Svc Contract Parts ori"
{
    Access = Internal;

    /// <summary>Declares the plain-number subject alternative and JSON version 1.0 envelope.</summary>
    internal procedure GetEnvelope(var Envelope: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'documentNo');
        Subject.Add('description', 'Optional plain service document number. Every supplied identifier must agree.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Describes the shared service document identity alternatives.</summary>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.no', 'document no.', 'Service document number in the message type''s document scope.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Service Header SystemId. The document type must match the message type.'));
        Target.Add(Contract.TargetEntry('subject', 'document no.', 'Plain service document number, as an alternative to data.no.'));
    end;

    /// <summary>Declares the common optional identifiers, at least one of which must be supplied.</summary>
    internal procedure GetIdentityParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Service document number, at most 20 characters. Required unless systemId or plain subject is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty Service Header GUID. Every supplied identifier must identify the same document.'));
    end;

    /// <summary>Declares shared validation errors; operation-specific callers add their own business refusals.</summary>
    internal procedure GetIdentityErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No document identifier was supplied.', 'Send no, systemId or a plain subject.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'An identifier is empty, too long or identifies the wrong document type.', 'Use an identifier in the documented document scope.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier is not a JSON string or systemId is not a GUID.', 'Correct the identifier type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The service document was not found.', 'Read Service Header with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different service documents.', 'Send identifiers belonging to the same document.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several declared parameters are invalid; nothing changed.', 'Correct each returned parameter error.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Foundation rejected an undeclared parameter before executing the message type.', 'Remove the undeclared parameter.'));
    end;

    /// <summary>Describes the service release/reopen result.</summary>
    internal procedure GetReleaseResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Name: Text;
    begin
        foreach Name in 'status,documentType,documentNo,systemId,customerNo,customerName,releaseStatusBefore,releaseStatusAfter'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'string', 'Order identity or invariant state. Release states are Open and ReleasedToShip.'));
        Fields.Add(Contract.ResponseField('amount', 'number', 'Recalculated amount excluding VAT.'));
        Fields.Add(Contract.ResponseField('amountIncludingVAT', 'number', 'Recalculated amount including VAT.'));
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents lifecycle refusals and standard BC errors.</summary>
    internal procedure GetReleaseErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        GetIdentityErrors(Errors);
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The order is already in the target state or has nothing to release.', 'Use Service.Order.Reopen to change a released order; otherwise add a line with type and quantity.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central rejected the operation; its error text is returned.', 'Correct the BC error and retry.'));
    end;

    /// <summary>Declares a non-idempotent transactional write; Foundation adds Retryable.</summary>
    internal procedure GetReleaseEffect(var Effect: JsonObject)
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Changes Service Header Release Status through standard BC release/reopen, recalculating VAT and warehouse requests.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Svc ori');
        Effect.Add('preconditions', 'Existing service order in the opposite release state; standard BC service validation applies.');
    end;

    /// <summary>Links the service lifecycle operations.</summary>
    internal procedure GetReleaseRelated(var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Service.Order.Release', 'Release an open order for warehouse handling.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Reopen', 'Reopen a released order to change it.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read Service Header and Service Line.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Edit ordinary service fields, excluding Release Status.'));
    end;

    /// <summary>Documents the quote, allocation, release and posting sequence.</summary>
    internal procedure GetServiceWorkflow(var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Service.Allocation.Allocate', 'Allocate or reallocate a resource on a service order.'));
        Steps.Add(Contract.WorkflowStep('Service.Order.Release', 'Release an open order for warehouse handling.'));
        Steps.Add(Contract.WorkflowStep('Service.Order.Reopen', 'Reopen a released order when further edits are needed.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('description', 'The planned complete service job is Service.Quote.MakeOrder, Service.Allocation.Allocate, Service.Order.Release, then Service.Order.Post. Allocation, release and reopen are provided. Quote conversion and posting are delivered by subsequent service lifecycle stories.');
    end;

    /// <summary>Declares the allocation request parameters, including the order identity alternatives.</summary>
    internal procedure GetAllocationParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Service order number, at most 20 characters. Required unless systemId, entryNo or a plain subject is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty Service Header GUID of a service order. Every supplied identifier must identify the same order.'));
        Parameters.Add(Contract.Parameter('entryNo', 'integer', false, 'Service Order Allocation entry number. It can identify the order and line on its own.'));
        Parameters.Add(Contract.Parameter('serviceItemLineNo', 'integer', false, 'Service item line number. Required when the order has more than one service item line and entryNo is not sent.'));
        Parameters.Add(Contract.Parameter('resourceNo', 'string', false, 'Resource to allocate. Required unless resourceGroupNo is supplied.'));
        Parameters.Add(Contract.Parameter('resourceGroupNo', 'string', false, 'Resource group to allocate. Required unless resourceNo is supplied.'));
        Parameters.Add(Contract.Parameter('allocationDate', 'string', false, 'Allocation date as yyyy-mm-dd. Defaults to the work date.'));
        Parameters.Add(Contract.Parameter('allocatedHours', 'number', true, 'Hours to allocate. Must be greater than 0.'));
        Parameters.Add(Contract.Parameter('startingTime', 'string', false, 'Optional starting time as hh:mm.'));
        Parameters.Add(Contract.Parameter('finishingTime', 'string', false, 'Optional finishing time as hh:mm. It cannot be earlier than startingTime.'));
        Parameters.Add(Contract.Parameter('reasonCode', 'string', false, 'Reason code stored on the new entry when an allocation is moved to another resource.'));
        Parameters.Add(Contract.Parameter('acceptOutsideServiceZone', 'boolean', false, 'Acknowledges that the resource does not work in the order service zone. Default is false.'));
    end;

    /// <summary>Describes the allocation result, including reallocation fields when an entry was moved.</summary>
    internal procedure GetAllocationResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'Service order number.'));
        Fields.Add(Contract.ResponseField('serviceItemLineNo', 'integer', 'Service item line that was allocated.'));
        Fields.Add(Contract.ResponseField('serviceItemNo', 'string', 'Service item on that line.'));
        Fields.Add(Contract.ResponseField('entryNo', 'integer', 'Active allocation entry after the call.'));
        Fields.Add(Contract.ResponseField('previousEntryNo', 'integer', 'Canceled or finished entry. Present only when reallocated is true.'));
        Fields.Add(Contract.ResponseField('previousStatus', 'string', 'Canceled or Finished. Present only when reallocated is true.'));
        Fields.Add(Contract.ResponseField('allocationStatus', 'string', 'Active.'));
        Fields.Add(Contract.ResponseField('resourceNo', 'string', 'Allocated resource. Empty when only a resource group was allocated.'));
        Fields.Add(Contract.ResponseField('resourceGroupNo', 'string', 'Allocated resource group. Taken from the resource card when only resourceNo is sent.'));
        Fields.Add(Contract.ResponseField('allocationDate', 'string', 'Allocation date as yyyy-mm-dd.'));
        Fields.Add(Contract.ResponseField('allocatedHours', 'number', 'Allocated hours.'));
        Fields.Add(Contract.ResponseField('reallocated', 'boolean', 'True when an Active or Reallocation Needed entry was moved.'));
        Fields.Add(Contract.ResponseField('repairStatusCode', 'string', 'Repair status of the service item line after the call.'));
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents allocation validation, zone and standard BC refusals. Foundation adds Retryable.</summary>
    internal procedure GetAllocationErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'An order identifier, entryNo, allocatedHours or a resource was not supplied.', 'Send documentNo, systemId, entryNo or a plain subject, allocatedHours, and resourceNo or resourceGroupNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value is empty, out of range or not allowed for the field.', 'Correct the named parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value is not the documented JSON type or format.', 'Use a string, number, integer, boolean, yyyy-mm-dd or hh:mm as documented.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The service order, allocation entry, service item line, resource or resource group was not found.', 'Read the record with Data.Records.Get and send an existing identifier.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, 'The order has more than one service item line and serviceItemLineNo was not sent.', 'Send serviceItemLineNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different orders or lines.', 'Send identifiers belonging to the same allocation.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The order or line cannot be allocated, no open entry exists, or the resource is outside the service zone.', 'Correct the order, choose a resource in the zone, or send acceptOutsideServiceZone = true.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central rejected the allocation; its error text is returned.', 'Correct the BC error and retry.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several declared parameters are invalid; nothing changed.', 'Correct each returned parameter error.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Foundation rejected an undeclared parameter before executing the message type.', 'Remove the undeclared parameter.'));
    end;

    /// <summary>Declares a non-idempotent allocation write under the caller's service permissions.</summary>
    internal procedure GetAllocationEffect(var Effect: JsonObject)
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Allocates or reallocates a Service Order Allocation entry through standard BC allocation, without running a modal page.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Svc ori');
        Effect.Add('preconditions', 'Existing service order with an open allocation entry. An Active or Reallocation Needed entry is moved; a Nonactive entry is allocated.');
    end;

    /// <summary>Links allocation to quote conversion, release and ordinary reads.</summary>
    internal procedure GetAllocationRelated(var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Service.Allocation.Allocate', 'Allocate or reallocate a resource on a service order.'));
        Related.Add(Contract.RelatedEntry('Service.Quote.MakeOrder', 'Convert a service quote. Active quote allocations arrive on the order as Reallocation Needed.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Release', 'Release the order for warehouse handling after allocation.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read Service Order Allocation, Service Header and Service Item Line.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Edit Allocated Hours and Allocation Date. Status, Resource No. and Resource Group No. stay on this message type.'));
    end;

    /// <summary>Shows a plain allocation and a reallocation payload.</summary>
    internal procedure GetAllocationExamples(var Examples: JsonArray)
    var
        Plain: JsonObject;
        Moved: JsonObject;
        PlainData: JsonObject;
        MovedData: JsonObject;
    begin
        PlainData.Add('documentNo', 'SO000001');
        PlainData.Add('resourceNo', 'LINA');
        PlainData.Add('allocationDate', '2026-11-03');
        PlainData.Add('allocatedHours', 2);
        Plain.Add('description', 'Allocate LINA for two hours on the only service item line.');
        Plain.Add('data', PlainData);
        Examples.Add(Plain);
        MovedData.Add('documentNo', 'SO000001');
        MovedData.Add('resourceNo', 'MARTY');
        MovedData.Add('allocatedHours', 2);
        MovedData.Add('reasonCode', 'MOVE');
        Moved.Add('description', 'Move an active allocation to MARTY and store the reason code on the new entry.');
        Moved.Add('data', MovedData);
        Examples.Add(Moved);
    end;

    /// <summary>Shows the common order identifier payload.</summary>
    internal procedure GetReleaseExamples(var Examples: JsonArray)
    var
        Example: JsonObject;
        Data: JsonObject;
    begin
        Data.Add('no', 'SO000001');
        Example.Add('description', 'Send this data to Service.Order.Release or Service.Order.Reopen.');
        Example.Add('data', Data);
        Examples.Add(Example);
    end;
}
