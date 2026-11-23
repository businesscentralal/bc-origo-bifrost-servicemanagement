namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Provides English contract chapters for service contract lifecycle operations.</summary>
codeunit 10076149 "Svc Contract Help ori"
{
    Access = Internal;

    /// <summary>Describes the plain-number subject and version.</summary>
    internal procedure GetEnvelope(var Envelope: JsonObject; Operation: Text)
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetEnvelope(Envelope);
    end;

    /// <summary>Describes the contract identity alternatives.</summary>
    internal procedure GetTarget(var Target: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.' + NumberKey(Operation), 'contract number', 'Select one service contract, or a contract quote for conversion.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Select the same contract by its system identifier.'));
        Target.Add(Contract.TargetEntry('subject', 'contract number', 'Plain contract number. Every supplied identifier must agree.'));
    end;

    /// <summary>Declares identity, count and explicit native choices.</summary>
    internal procedure GetParameters(var Parameters: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter(NumberKey(Operation), 'string', false, 'Contract number, at most 20 characters. Required unless systemId or plain subject is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty GUID of the selected contract or contract quote. All supplied identifiers must agree.'));
        if Operation in ['Make', 'Sign'] then begin
            Parameters.Add(Contract.Parameter('expectedCount', 'integer', false, 'Explicit confirmation of one contract. Omission returns ConfirmationRequired and count 1; send 1 to proceed.'));
            Parameters.Add(Contract.Parameter('createInvoice', 'boolean', false, 'Create the initial unposted invoice when the initial period requires it. Default true, matching the native Yes default. False signs without that invoice.'));
            Parameters.Add(Contract.Parameter('addLinesStartingLater', 'boolean', false, 'Accept lines starting after the contract starting date. Default true. False refuses those lines before signing.'));
            Parameters.Add(Contract.Parameter('acceptMissingServiceDate', 'boolean', false, 'Accept lines with an empty next planned service date. Default true, matching the native Yes default. False refuses before signing.'));
            Parameters.Add(Contract.Parameter('acceptNonMonthEndInvoiceDate', 'boolean', false, 'Accept a non-prepaid next invoice date that is not month end. Default true, matching the native Yes default. False refuses before signing.'));
        end;
    end;

    /// <summary>Describes persisted identity, status and invoice information.</summary>
    internal procedure GetResponse(var Response: JsonObject; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Name: Text;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        foreach Name in 'contractNo,systemId,contractStatus,changeStatusBefore,changeStatusAfter,nextInvoiceDate,nextInvoicePeriodStart,nextInvoicePeriodEnd,invoiceNo,nextStep'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'string', 'Persisted contract state, ISO date, newly created unposted invoice number (empty if none), or next operation.'));
        if Operation = 'Make' then begin
            Fields.Add(Contract.ResponseField('contractQuoteNo', 'string', 'The quote that was filed and removed.'));
            Fields.Add(Contract.ResponseField('filedQuoteEntryNo', 'integer', 'Entry number of the filed quote.'));
        end;
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents structured refusals and recovery steps.</summary>
    internal procedure GetErrors(var Errors: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No contract identifier was supplied.', 'Send the contract number, systemId or plain subject.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier, count or boolean has an invalid format.', 'Send values using the documented JSON types.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The identifier selects the wrong document scope.', 'Select a contract quote for conversion or a contract for signing, locking and unlocking.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared request key was supplied.', 'Remove the undeclared key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected contract or quote does not exist.', 'Read the contracts and send an existing identifier. A converted quote has been removed.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Supplied identifiers select different contracts.', 'Send identifiers for the same contract.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The service write role or native permissions are missing.', 'Ask an administrator for the service write role and native contract permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The requested change status is already set, a date choice was refused, or a signed contract has new lines.', 'Review the contract and requested choices. Complete new-line addenda in the client before locking.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the operation; its own reason is returned. Nothing was changed.', 'Correct the named field or setup and retry.'));
        if Operation in ['Make', 'Sign'] then begin
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'One contract requires explicit confirmation.', 'Send expectedCount: 1.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'The supplied count is not one.', 'Review the selected contract and send expectedCount: 1.'));
        end;
    end;

    /// <summary>Classifies non-posting operations as writes under the 21 November ruling.</summary>
    internal procedure GetEffect(var Effect: JsonObject; Operation: Text)
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Svc ori');
        Effect.Add('changes', 'Updates the service contract through the native lifecycle. Conversion files and removes the quote and creates a signed, locked contract. Signing can create an unposted invoice; no invoice is posted.');
        Effect.Add('preconditions', 'Service write role, native contract permissions and valid contract setup. Conversion and signing additionally require explicit expectedCount: 1.');
    end;

    /// <summary>Links the contract operations and subsequent invoice posting.</summary>
    internal procedure GetRelated(var Related: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Name: Text;
    begin
        foreach Name in 'Service.ContractQuote.MakeContract,Service.Contract.Sign,Service.Contract.Lock,Service.Contract.Unlock,Service.Document.Post'.Split(',') do
            Related.Add(Contract.RelatedEntry(Name, 'Continue the service contract and billing lifecycle.'));
    end;

    /// <summary>Describes the quote and existing-contract routes.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject; Operation: Text)
    begin
        Workflow.Add('description', 'Create a contract quote and its service item lines, then convert it. Conversion already signs and locks the resulting contract. Alternatively sign an unsigned contract. Unlock to edit, lock when complete, and review any unposted invoice before posting it.');
    end;

    /// <summary>Provides a concrete single-contract request.</summary>
    internal procedure GetExamples(var Examples: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Request: JsonObject;
        Data: JsonObject;
        RequestText: Text;
        Name: Text;
    begin
        Name := 'Service.Contract.' + Operation;
        if Operation = 'Make' then
            Name := 'Service.ContractQuote.MakeContract';
        Data.Add(NumberKey(Operation), 'XCONTRACT001');
        if Operation in ['Make', 'Sign'] then begin
            Data.Add('expectedCount', 1);
            Data.Add('createInvoice', false);
        end;
        Request.Add('type', Name);
        Request.Add('data', Data);
        Request.WriteTo(RequestText);
        Examples.Add(Contract.Example('Operate on one service contract', RequestText, '{"status":"Success","contractNo":"XCONTRACT001"}'));
    end;

    local procedure NumberKey(Operation: Text): Text
    begin
        if Operation = 'Make' then
            exit('contractQuoteNo');
        exit('contractNo');
    end;
}
