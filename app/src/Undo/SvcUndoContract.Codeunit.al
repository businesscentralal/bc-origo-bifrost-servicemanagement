namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Contract chapters shared by Service.Shipment.Undo and Service.Consumption.Undo.</summary>
codeunit 10076093 "Svc Undo Contract ori"
{
    Access = Internal;

    /// <summary>Lists the type only for callers holding the posting token and write permission on service lines.</summary>
    /// <returns>True when the caller may undo.</returns>
    internal procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Svc Posting Gate ori";
        LineRef: RecordRef;
    begin
        if not Gate.HasPostingPermission() then
            exit(false);
        LineRef.Open(Database::"Service Line");
        exit(LineRef.WritePermission());
    end;

    /// <summary>Declares the plain-number subject and version 1.0 envelope.</summary>
    /// <param name="Envelope">The envelope chapter.</param>
    internal procedure GetEnvelope(var Envelope: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'documentNo');
        Subject.Add('description', 'Optional plain posted service shipment number. Every supplied identifier must agree.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Describes the posted shipment identity alternatives.</summary>
    /// <param name="Target">The target chapter.</param>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.documentNo', 'document no.', 'Posted service shipment number (Service Shipment Header).'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Service Shipment Header SystemId.'));
        Target.Add(Contract.TargetEntry('subject', 'document no.', 'Plain posted service shipment number, as an alternative to data.documentNo.'));
    end;

    /// <summary>Declares the shipment identity and the line selection.</summary>
    /// <param name="Parameters">The parameters chapter.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    internal procedure GetParameters(var Parameters: JsonArray; Consumption: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Posted service shipment number, at most 20 characters. Required unless systemId or plain subject is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty Service Shipment Header GUID. Every supplied identifier must identify the same shipment.'));
        if Consumption then
            Parameters.Add(Contract.Parameter('lineNos', 'array', false, 'Line No. values of the shipment lines whose consumption is undone: 1 to 200 distinct positive whole numbers. Leave out to undo every line that has consumed quantity and was not invoiced.'))
        else
            Parameters.Add(Contract.Parameter('lineNos', 'array', false, 'Line No. values of the shipment lines to undo: 1 to 200 distinct positive whole numbers. Leave out to undo every line that can be undone (shipped, not consumed, not invoiced, no service items created).'));
    end;

    /// <summary>Describes the success response.</summary>
    /// <param name="Response">The response chapter.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    internal procedure GetResponse(var Response: JsonObject; Consumption: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        LineFields: JsonArray;
        LineObject: JsonObject;
        Name: Text;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'The posted service shipment.'));
        Fields.Add(Contract.ResponseField('serviceOrderNo', 'string', 'The service order the quantities return to.'));
        Fields.Add(Contract.ResponseField('reversedLineNos', 'array', 'Line No. of every shipment line that was undone.'));
        Fields.Add(Contract.ResponseField('reversedCount', 'integer', 'Number of lines undone.'));
        LineFields.Add(Contract.ResponseField('lineNo', 'integer', 'The undone shipment line.'));
        LineFields.Add(Contract.ResponseField('type', 'string', 'Line type (Item, Resource, Cost, G/L Account).'));
        LineFields.Add(Contract.ResponseField('no', 'string', 'Item, resource, cost or account number.'));
        LineFields.Add(Contract.ResponseField('quantity', 'number', 'Quantity of the undone line.'));
        LineFields.Add(Contract.ResponseField('correctionLineNo', 'integer', 'The correction line inserted on the posted shipment.'));
        LineFields.Add(Contract.ResponseField('orderLineNo', 'integer', 'The service order line the quantity returns to.'));
        foreach Name in 'quantityShipped,quantityConsumed,outstandingQuantity,qtyToShip,qtyToConsume'.Split(',') do
            LineFields.Add(Contract.ResponseField(Name, 'number', 'Quantities on the service order line after the undo.'));
        if Consumption then
            LineObject := Contract.ResponseField('lines', 'array', 'One entry per undone line; quantityConsumed shows the consumption returned to the order line.')
        else
            LineObject := Contract.ResponseField('lines', 'array', 'One entry per undone line; outstandingQuantity and qtyToShip show the quantity back on the order line.');
        LineObject.Add('children', LineFields);
        Fields.Add(LineObject);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares every refusal.</summary>
    /// <param name="Errors">The errors chapter.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    internal procedure GetErrors(var Errors: JsonArray; Consumption: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No shipment identifier was supplied.', 'Send documentNo, systemId or a plain subject.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'An identifier is empty or too long, or lineNos is empty, longer than 200, has duplicates or a number below 1.', 'Correct the parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier is not a JSON string, systemId is not a GUID, lineNos is not an array of whole numbers, or a requested line is a correction line or was already undone.', 'Send original lines only, as whole numbers.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The posted service shipment, or a requested line on it, was not found.', 'Read Service Shipment Header and Service Shipment Line with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'documentNo, systemId and subject name different shipments.', 'Send identifiers belonging to the same shipment.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several identifiers are invalid; nothing was posted.', 'Correct each returned parameter error.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter was sent.', 'Remove the undeclared parameter.'));
        if Consumption then
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A requested line has no consumed quantity, was invoiced, or its service order line no longer exists; or no line can be undone.', 'Use Service.Shipment.Undo for lines that were not consumed; correct invoiced lines with a service credit memo in Business Central.'))
        else begin
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A requested line has consumed quantity, was invoiced, or its service order line no longer exists; or no line can be undone.', 'Undo consumption first with Service.Consumption.Undo; correct invoiced lines with a service credit memo in Business Central.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The shipment of a requested line created service items; the undo would delete them, so the line is refused and nothing is deleted.', 'Undo the line in Business Central, where you decide about the service items, or correct it with a service credit memo.'));
        end;
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the undo (for example applied item entries or warehouse handling); its text is returned and nothing was posted.', 'Correct the Business Central error and retry, or use a service credit memo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the BIFROST SvcPost ori permission set.', 'Ask an administrator to assign BIFROST SvcPost ori.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'expectedCount was not sent. The answer lists the lines that would be undone.', 'Send expectedCount 1 (the one posted shipment).'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount is not 1.', 'Send expectedCount 1 (the one posted shipment, not the number of lines).'));
    end;

    /// <summary>Declares the effect chapter.</summary>
    /// <param name="Effect">The effect chapter.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    internal procedure GetEffect(var Effect: JsonObject; Consumption: Boolean)
    begin
        Effect.Add('effect', 'irreversible');
        if Consumption then
            Effect.Add('changes', 'Posts correcting item and resource journal lines, reverses the consumption service ledger and warranty entries, inserts correction lines on the posted shipment and puts the consumed quantity back on the service order line. The posted shipment is kept; nothing is deleted. This call commits and cannot be undone.')
        else
            Effect.Add('changes', 'Posts correcting item and resource journal lines, reverses the service ledger and warranty entries, inserts correction lines on the posted shipment and puts the shipped quantity back on the service order line. The posted shipment is kept; nothing is deleted. This call commits and cannot be undone.');
        Effect.Add('expectedCount', 'The one posted service shipment, not its lines: send 1.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST SvcPost ori');
        Effect.Add('preconditions', 'The lines were shipped (and, for consumption undo, consumed) but not invoiced, the service order line still exists, and the item entries are not applied.');
    end;

    /// <summary>Declares the related types.</summary>
    /// <param name="Related">The related chapter.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    internal procedure GetRelated(var Related: JsonArray; Consumption: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Consumption then
            Related.Add(Contract.RelatedEntry('Service.Shipment.Undo', 'Undo a shipped line that was not consumed.'))
        else
            Related.Add(Contract.RelatedEntry('Service.Consumption.Undo', 'The line was consumed; undo the consumption first.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Post', 'Ship or consume the corrected quantities again.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read Service Shipment Header and Service Shipment Line to find the shipment and line numbers.'));
    end;

    /// <summary>Returns the examples.</summary>
    /// <param name="Examples">The examples chapter.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    internal procedure GetExamples(var Examples: JsonArray; Consumption: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        TypeName: Text;
    begin
        TypeName := 'Service.Shipment.Undo';
        if Consumption then
            TypeName := 'Service.Consumption.Undo';
        Examples.Add(Contract.Example('Undo one line', '{"type":"' + TypeName + '","data":{"documentNo":"SVC-SHIP1","lineNos":[10000],"expectedCount":1}}',
            '{"status":"Success","documentNo":"SVC-SHIP1","serviceOrderNo":"SVC-ORDER1","reversedLineNos":[10000],"reversedCount":1,"lines":[{"lineNo":10000,"type":"Item","no":"1000","quantity":2,"correctionLineNo":15000,"orderLineNo":10000,"quantityShipped":0,"quantityConsumed":0,"outstandingQuantity":2,"qtyToShip":2,"qtyToConsume":0}]}'));
        Examples.Add(Contract.Example('Undo every line that can be undone', '{"type":"' + TypeName + '","data":{"documentNo":"SVC-SHIP1","expectedCount":1}}', '{"status":"Success","documentNo":"SVC-SHIP1","reversedCount":2}'));
        Examples.Add(Contract.Example('Ask first (no expectedCount)', '{"type":"' + TypeName + '","data":{"documentNo":"SVC-SHIP1"}}', '{"status":"Error","code":"ConfirmationRequired","count":1}'));
    end;

    /// <summary>Returns the shared notes.</summary>
    /// <param name="Consumption">True for consumption undo.</param>
    /// <returns>The notes text.</returns>
    internal procedure GetNotes(Consumption: Boolean): Text
    var
        Notes: Text;
    begin
        Notes := 'This call commits, including when Omit Commit is requested; Business Central''s own undo posting is kept. In an AL rollback chain (Omit Commit), a native error is raised to the caller unchanged; normal calls return BusinessCentralError JSON. Every requested line is checked before anything is posted. Not retry-safe: an undone line becomes a correction line and is refused the next time.';
        if not Consumption then
            Notes += ' Lines whose shipment created service items are refused, because the undo would delete those service items.';
        exit(Notes);
    end;

    /// <summary>Returns the service workflow.</summary>
    /// <param name="Workflow">The workflow chapter.</param>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetServiceWorkflow(Workflow);
    end;
}
