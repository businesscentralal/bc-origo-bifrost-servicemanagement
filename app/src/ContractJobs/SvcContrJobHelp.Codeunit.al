namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Documents the bounded contract periodic operations in English.</summary>
codeunit 10076170 "Svc Contr Job Help ori"
{
    Access = Internal;

    /// <summary>Describes the common envelope.</summary>
    internal procedure GetEnvelope(var Envelope: JsonObject; Operation: Text)
    var
        Parts: Codeunit "Svc Contract Parts ori";
        Subject: JsonObject;
    begin
        Parts.GetEnvelope(Envelope);
        if Operation = 'Credit' then begin
            Subject.Add('use', 'contractNo');
            Subject.Add('description', 'Optional plain contract number. Every supplied identifier must agree.');
        end else begin
            Subject.Add('use', 'none');
            Subject.Add('description', 'Leave subject empty; select contracts using data.contractNos or the documented filters.');
        end;
        Envelope.Replace('subject', Subject);
        Envelope.Replace('dataRequired', true);
    end;

    /// <summary>Describes single-contract and batch scopes.</summary>
    internal procedure GetTarget(var Target: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Operation = 'Credit' then begin
            Target.Add(Contract.TargetEntry('data.contractNo', 'contract number', 'One signed, locked contract. All supplied identifiers must agree.'));
            Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'The same contract by its system identifier.'));
            Target.Add(Contract.TargetEntry('subject', 'contract number', 'Plain contract number.'));
        end else
            Target.Add(Contract.TargetEntry('data.contractNos', 'array', '1 to 200 distinct signed, locked contracts; alternatively use customerNo or nextInvoiceDateTo filters. No subject for batches.'));
    end;

    /// <summary>Declares all accepted keys and strict date bounds.</summary>
    internal procedure GetParameters(var Parameters: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('expectedCount', 'integer', false, 'Counts distinct selected contracts, not created documents. Omit to review the count and list without changes; resend that count to confirm.'));
        if Operation = 'Credit' then begin
            Parameters.Add(Contract.Parameter('contractNo', 'string', false, 'Contract number, at most 20 characters; required unless systemId or subject is supplied.'));
            Parameters.Add(Contract.Parameter('systemId', 'string', false, 'GUID of the same contract. Conflicting identifiers are refused.'));
            Parameters.Add(Contract.Parameter('creditMemoDateTo', 'string', false, 'ISO date YYYY-MM-DD, default work date; cannot exceed work date. Only uncredited lines due by this date are processed.'));
        end else begin
            Parameters.Add(Contract.Parameter('contractNos', 'array', false, '1 to 200 contract numbers, each at most 20 characters. Duplicates count once. Do not combine with filters.'));
            Parameters.Add(Contract.Parameter('customerNo', 'string', false, 'Exact customer number, at most 20 characters. Used alone or together with nextInvoiceDateTo instead of contractNos.'));
            Parameters.Add(Contract.Parameter('nextInvoiceDateTo', 'string', false, 'ISO date YYYY-MM-DD. Select contracts with a nonempty next invoice date on or before this date.'));
            if Operation = 'Invoices' then begin
                Parameters.Add(Contract.Parameter('postingDate', 'string', true, 'Posting date for unposted invoices, in YYYY-MM-DD format. Nothing is posted.'));
                Parameters.Add(Contract.Parameter('invoiceToDate', 'string', true, 'Include invoice periods due by this ISO date. Each selected contract is processed separately.'));
            end else begin
                Parameters.Add(Contract.Parameter('startingDate', 'string', true, 'First planned service date, in YYYY-MM-DD format.'));
                Parameters.Add(Contract.Parameter('endingDate', 'string', true, 'Last planned service date, inclusive. Must be on or after startingDate and before its one-year anniversary. The company maximum service-order period also applies.'));
            end;
        end;
    end;

    /// <summary>Describes actual documents, selected contracts and skipped work.</summary>
    internal procedure GetResponse(var Response: JsonObject; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('count', 'integer', 'Number of distinct contracts confirmed and processed.'));
        Fields.Add(Contract.ResponseField('contractsProcessed', 'array', 'Selected contract numbers, including those with no eligible work.'));
        Fields.Add(Contract.ResponseField('contractsSkipped', 'array', 'contractNo and localized reason when no invoice or service item line was created.'));
        Fields.Add(Contract.ResponseField('invoicesCreated', 'array', 'New unposted invoices: no, contractNo, customerNo and amount excluding VAT.'));
        Fields.Add(Contract.ResponseField('serviceOrdersCreated', 'array', 'One entry per item line on new orders: no, contractNo, serviceItemNo and lineNo.'));
        Fields.Add(Contract.ResponseField('linesAddedToExistingOrders', 'array', 'New item lines on existing pending orders: no, contractNo, serviceItemNo and lineNo.'));
        Fields.Add(Contract.ResponseField('creditMemos', 'array', 'One entry per successfully credited contract line: no, contractNo and lineNo. A memo can contain several credited lines. No eligible lines returns an empty array.'));
        Fields.Add(Contract.ResponseField('nextStep', 'string', 'Localized guidance for reviewing and separately posting documents.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents all structured refusals and recovery guidance.</summary>
    internal procedure GetErrors(var Errors: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No contracts or required dates were supplied, or filters selected none.', 'Select contracts and supply the required ISO dates.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier, date, count or date range is invalid.', 'Correct the value; service order periods cannot exceed one year.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared request key was supplied.', 'Remove the undeclared key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A selected contract does not exist.', 'Read contracts and send an existing contract number.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers disagree, or a batch mixes a contract list with filters or a subject.', 'Select one consistent scope.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The service write role or native permissions are missing.', 'Ask an administrator for the service write role and native service contract permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A contract is unsigned or unlocked, or more than 200 contracts were selected.', 'Sign and lock the contracts, or narrow the scope.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'The selected contract count and list require confirmation. Nothing changed.', 'Review count and contractNos, then resend expectedCount with that count.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount differs from the selected contract count. Nothing changed.', 'Review count and contractNos, then resend the correct count.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the operation; its reason is returned. All changes roll back.', 'Correct the named setup or contract fields and retry.'));
    end;

    /// <summary>Classifies unposted document creation as a write with explicit scope confirmation.</summary>
    internal procedure GetEffect(var Effect: JsonObject; Operation: Text)
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Svc ori');
        Effect.Add('changes', 'Creates unposted invoices, preventive service orders or unposted credit memos. Advances invoice or planned service dates, or marks contract lines credited. Service order processing also updates the company last contract service date. No records are deleted and no documents are posted.');
        Effect.Add('preconditions', 'Signed, locked contracts; 1 to 200 contracts; valid dates; explicit expectedCount equal to the selected contract count; service write role and native permissions.');
    end;

    /// <summary>Links contract preparation, posting and reads.</summary>
    internal procedure GetRelated(var Related: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Name: Text;
    begin
        foreach Name in 'Service.Contract.Sign,Service.Contract.Lock,Service.Document.Post,Data.Records.Get'.Split(',') do
            Related.Add(Contract.RelatedEntry(Name, 'Prepare contracts, review results or separately post created billing documents.'));
    end;

    /// <summary>Explains confirmation and review.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject; Operation: Text)
    begin
        Workflow.Add('description', 'Select signed and locked contracts and dates. Omit expectedCount to review the selected count and list, then resend the count to confirm. Review created documents before posting separately. Retry only after reading the current contract and document state.');
    end;

    /// <summary>Provides a complete concrete request.</summary>
    internal procedure GetExamples(var Examples: JsonArray; Operation: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Request: JsonObject;
        Data: JsonObject;
        Numbers: JsonArray;
        RequestText: Text;
        Name: Text;
    begin
        Data.Add('expectedCount', 1);
        if Operation = 'Credit' then begin
            Name := 'Service.Contract.CreateCreditMemo';
            Data.Add('contractNo', 'XCONTRACT001');
        end else begin
            Numbers.Add('XCONTRACT001');
            Data.Add('contractNos', Numbers);
            if Operation = 'Invoices' then begin
                Name := 'Service.Contract.CreateInvoices';
                Data.Add('postingDate', '2026-01-31');
                Data.Add('invoiceToDate', '2026-01-31');
            end else begin
                Name := 'Service.Contract.CreateServiceOrders';
                Data.Add('startingDate', '2026-01-01');
                Data.Add('endingDate', '2026-01-31');
            end;
        end;
        Request.Add('type', Name);
        Request.Add('data', Data);
        Request.WriteTo(RequestText);
        Examples.Add(Contract.Example('Run one confirmed contract', RequestText, '{"status":"Success","count":1}'));
    end;
}
