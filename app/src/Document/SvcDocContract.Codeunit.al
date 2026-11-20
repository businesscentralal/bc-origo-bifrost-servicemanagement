namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>English contract chapters for standalone service billing.</summary>
codeunit 10076100 "Svc Doc Contract ori"
{
    Access = Internal;

    /// <summary>Describes the supported envelope.</summary>
    internal procedure GetEnvelope(var Envelope: JsonObject; Mode: Text)
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetEnvelope(Envelope);
    end;

    /// <summary>Describes document identity alternatives.</summary>
    internal procedure GetTarget(var Target: JsonArray; Mode: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Mode = 'Shipment' then begin
            Target.Add(Contract.TargetEntry('data.invoiceNo', 'document no.', 'An open service invoice.'));
            Target.Add(Contract.TargetEntry('data.customerNo', 'customer no.', 'Create an invoice for this customer instead of selecting an invoice.'));
        end else
            Target.Add(Contract.TargetEntry('data.no', 'document no.', 'An invoice or credit memo of the requested documentType.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'The unposted service document identifier.'));
        Target.Add(Contract.TargetEntry('subject', 'document no.', 'Plain document number; every supplied identifier must agree.'));
    end;

    /// <summary>Declares standalone document identity parameters.</summary>
    internal procedure GetDocumentParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentType', 'string', true, 'Invoice or CreditMemo. Orders use Service.Order.Post and Service.Order.PreviewPost.'));
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Unposted document number; alternative to systemId or subject.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty document GUID. Every supplied identifier must agree.'));
    end;

    /// <summary>Declares shipment collection parameters.</summary>
    internal procedure GetShipmentParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('invoiceNo', 'string', false, 'An open invoice number; alternative to systemId or subject.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty document GUID. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('customerNo', 'string', false, 'Create a new invoice for this customer; cannot be combined with invoice identifiers.'));
        Parameters.Add(Contract.Parameter('shipmentNos', 'array', false, '1 to 200 distinct posted shipment numbers. Required unless allUninvoiced is true.'));
        Parameters.Add(Contract.Parameter('allUninvoiced', 'boolean', false, 'Select shipments matching the invoice customer, bill-to customer and currency. Cannot be combined with shipmentNos.'));
    end;

    /// <summary>Describes returned identity, totals and posting or collection results.</summary>
    internal procedure GetResponse(var Response: JsonObject; Mode: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        ParameterInfo: JsonObject;
        Children: JsonArray;
        KeyName: Text;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        case Mode of
            'Shipment': begin
            Fields.Add(Contract.ResponseField('invoiceNo', 'string', 'The unposted invoice number.'));
            Fields.Add(Contract.ResponseField('systemId', 'string', 'The invoice identifier.'));
            Fields.Add(Contract.ResponseField('created', 'boolean', 'True when this call created the invoice.'));
            Fields.Add(Contract.ResponseField('linesAdded', 'integer', 'All inserted invoice lines, including native shipment description lines.'));
            Children.Add(Contract.ResponseField('shipmentNo', 'string', 'Selected shipment.'));
            Children.Add(Contract.ResponseField('linesAdded', 'integer', 'Invoice lines inserted for this shipment.'));
            ParameterInfo := Contract.ResponseField('shipments', 'array', 'Results for each selected shipment.');
            ParameterInfo.Add('children', Children);
            Fields.Add(ParameterInfo);
            Clear(Children);
            Children.Add(Contract.ResponseField('shipmentNo', 'string', 'Skipped shipment number.'));
            Children.Add(Contract.ResponseField('lineNo', 'integer', 'Skipped shipment line number.'));
            Children.Add(Contract.ResponseField('reason', 'string', 'Why the line was skipped, in the caller language.'));
            ParameterInfo := Contract.ResponseField('skipped', 'array', 'Already invoiced, consumed, corrected or already added lines.');
            ParameterInfo.Add('children', Children);
            Fields.Add(ParameterInfo);
            end;
            'Post': begin
                foreach KeyName in 'documentNo,documentType,customerNo,postedDocumentNo,systemId'.Split(',') do
                    Fields.Add(Contract.ResponseField(KeyName, 'string', 'Original or posted document identity; systemId belongs to the posted document.'));
                Fields.Add(Contract.ResponseField('amount', 'number', 'Posted amount excluding VAT.'));
                Fields.Add(Contract.ResponseField('amountIncludingVAT', 'number', 'Posted amount including VAT.'));
                foreach KeyName in 'customerFirst,customerLast,glFirst,glLast'.Split(',') do
                    Children.Add(Contract.ResponseField(KeyName, 'integer', 'First or last ledger entry for the posted document.'));
                ParameterInfo := Contract.ResponseField('entryRanges', 'object', 'Customer and general ledger entry number ranges.');
                ParameterInfo.Add('children', Children);
                Fields.Add(ParameterInfo);
            end;
            else begin
                Fields.Add(Contract.ResponseField('documentNo', 'string', 'The document previewed.'));
                Fields.Add(Contract.ResponseField('entryCount', 'integer', 'Total ledger entries in the preview.'));
                Fields.Add(Contract.ResponseField('glEntryCount', 'integer', 'General ledger entries in the preview.'));
                Fields.Add(Contract.ResponseField('rollback', 'boolean', 'Always true. Nothing remains posted.'));
                Fields.Add(Contract.ResponseField('summary', 'string', 'Localized preview summary.'));
                Fields.Add(Contract.ResponseField('totals', 'object', 'Preview totals.'));
                Fields.Add(Contract.ResponseField('preview', 'array', 'Captured entries grouped by ledger.'));
                foreach KeyName in 'ship,consume,invoice'.Split(',') do
                    Fields.Add(Contract.ResponseField(KeyName, 'boolean', 'Native posting options used for the preview.'));
            end;
        end;
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Lists structured refusals and recovery paths.</summary>
    internal procedure GetErrors(var Errors: JsonArray; Mode: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required document type, identity or shipment selection is missing.', 'Send the required parameters shown in help.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The requested document type is unsupported.', 'Use Invoice or CreditMemo; orders use Service.Order.Post.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value has an invalid JSON type or format.', 'Use strings for identifiers and an array of distinct strings for shipmentNos.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A requested document or customer does not exist.', 'Read the documents and customers, then use an existing identifier.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers disagree or a shipment has a different customer, bill-to customer or currency.', 'Select matching identifiers and shipments.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter was supplied.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several parameters are invalid.', 'Correct each returned parameter error.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the required role.', 'Ask an administrator for service write access and, for posting or preview, BIFROST SvcPost ori.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The document cannot be processed in its current state.', 'Use an open invoice for shipment collection and correct the reported document condition.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the operation; no partial document changes remain.', 'Correct the reported setup or document and retry.'));
        if Mode = 'Post' then begin
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'One document needs confirmation.', 'Review the document and send expectedCount 1.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'The expected count is not one document.', 'Review the document and send expectedCount 1.'));
        end;
    end;

    /// <summary>Declares write, irreversible posting or rolled-back preview effects.</summary>
    internal procedure GetEffect(var Effect: JsonObject; Mode: Text)
    begin
        case Mode of
            'Post': begin
                Effect.Add('effect', 'irreversible');
                Effect.Add('changes', 'Posts one invoice or credit memo, creates ledger entries and removes the unposted document through standard posting cleanup. Commits. expectedCount counts one document.');
                Effect.Add('permissionSet', 'BIFROST SvcPost ori');
            end;
            'Preview': begin
                Effect.Add('effect', 'read');
                Effect.Add('changes', 'Simulates posting and rolls back every entry.');
                Effect.Add('permissionSet', 'BIFROST SvcPost ori');
            end;
            'Shipment': begin
                Effect.Add('effect', 'write');
                Effect.Add('changes', 'Creates an invoice when requested and adds uninvoiced shipment lines. Nothing is posted.');
                Effect.Add('permissionSet', 'BIFROST Full ori');
            end;
        end;
        Effect.Add('idempotent', Mode = 'Preview');
    end;

    /// <summary>Names related operations.</summary>
    internal procedure GetRelated(var Related: JsonArray; Mode: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Service.Invoice.GetShipmentLines', 'Collect shipped lines on an invoice.'));
        Related.Add(Contract.RelatedEntry('Service.Document.PreviewPost', 'Inspect the ledger entries before posting.'));
        Related.Add(Contract.RelatedEntry('Service.Document.Post', 'Post the invoice or credit memo.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Post', 'Post an order instead.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read the document and its lines.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Prepare an invoice or credit memo.'));
    end;

    /// <summary>Describes the billing sequence.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject; Mode: Text)
    begin
        Workflow.Add('description', 'Ship service orders, collect their shipments on an invoice, preview it, then post with expectedCount 1. Create credit memos with Data.Records.Set and preview before posting.');
    end;

    /// <summary>Returns a request and response example.</summary>
    internal procedure GetExamples(var Examples: JsonArray; Mode: Text)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        case Mode of
            'Post': Examples.Add(Contract.Example('Post a credit memo', '{"type":"Service.Document.Post","data":{"documentType":"CreditMemo","no":"SCM0001","expectedCount":1}}', '{"status":"Success","documentType":"CreditMemo","documentNo":"SCM0001","postedDocumentNo":"PSCM0001"}'));
            'Preview': Examples.Add(Contract.Example('Preview an invoice', '{"type":"Service.Document.PreviewPost","data":{"documentType":"Invoice","no":"SI0001"}}', '{"status":"Success","documentNo":"SI0001","entryCount":3,"rollback":true}'));
            'Shipment': Examples.Add(Contract.Example('Combine shipments', '{"type":"Service.Invoice.GetShipmentLines","data":{"customerNo":"C0001","shipmentNos":["SS0001","SS0002"]}}', '{"status":"Success","invoiceNo":"SI0001","created":true,"linesAdded":4}'));
        end;
    end;

    /// <summary>Explains retry and transaction behavior.</summary>
    internal procedure GetNotes(var Notes: Text; Mode: Text)
    begin
        Notes := 'Every supplied identifier must agree. Orders stay on Service.Order.Post and Service.Order.PreviewPost. Shipment collection requires matching customer, bill-to customer and currency; already invoiced lines are skipped. Posting commits and standard posting cleanup removes the unposted document. Preview requires its own transaction and refuses Omit Commit. After uncertain posting success, inspect posted documents before retrying.';
    end;

    /// <summary>Summarizes the operation.</summary>
    internal procedure GetOverview(var Overview: Text; Mode: Text)
    begin
        case Mode of
            'Post': Overview := 'Posts one service invoice or credit memo after confirmation. Returns posted document identity, amounts and ledger entry ranges.';
            'Preview': Overview := 'Previews a service invoice or credit memo and returns ledger entries, then rolls back every change.';
            'Shipment': Overview := 'Collects uninvoiced service shipment lines on an open invoice, creating the invoice when customerNo is supplied. No posting occurs.';
        end;
    end;
}
