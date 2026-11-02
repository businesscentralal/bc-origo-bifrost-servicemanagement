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
        Steps.Add(Contract.WorkflowStep('Service.Order.Release', 'Release an open order for warehouse handling.'));
        Steps.Add(Contract.WorkflowStep('Service.Order.Reopen', 'Reopen a released order when further edits are needed.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('description', 'The planned complete service job is Service.Quote.MakeOrder, Service.Allocation.Allocate, Service.Order.Release, then Service.Order.Post. Quote conversion, allocation and posting are delivered by subsequent service lifecycle stories; only release/reopen are provided by this group.');
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
