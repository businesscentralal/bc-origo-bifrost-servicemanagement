namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Loaner;
using Origo.Bifrost;

/// <summary>Implements Service.Loaner.Receive through the standard Business Central loaner lifecycle.</summary>
codeunit 10076105 "Svc Loaner Receive Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        Processor: Codeunit "Svc Loaner Receive Proc ori";
    begin
        Processor.Dispatch(Argument);
    end;

    /// <summary>Enables discovery without reading application tables.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the loaner filter scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Loaner);
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Receives a lent loaner from an order, a posted shipment or its loaner number.', Comment = 'is-IS=Tekur við lánstæki úr útláni á pöntun, bókaðri afhendingu eða eftir númeri lánstækis.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'receive loaner, return loaner, loaner availability', Comment = 'is-IS=taka við lánstæki, skila lánstæki, framboð lánstækja';
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
        Target.Add(Contract.TargetEntry('data.documentNo + data.serviceItemLineNo', 'order line', 'An open service order item line.'));
        Target.Add(Contract.TargetEntry('data.postedShipmentNo + data.lineNo', 'shipment line', 'A posted service shipment item line.'));
        Target.Add(Contract.TargetEntry('data.loanerNo', 'loaner number', 'The loaner wherever it is currently lent. All supplied identifiers must name the same loan.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Service order number, at most 20 characters; requires serviceItemLineNo.'));
        Parameters.Add(Contract.Parameter('serviceItemLineNo', 'integer', false, 'Positive service item line number; requires documentNo.'));
        Parameters.Add(Contract.Parameter('postedShipmentNo', 'string', false, 'Posted service shipment number, at most 20 characters; requires lineNo.'));
        Parameters.Add(Contract.Parameter('lineNo', 'integer', false, 'Positive posted shipment item line number; requires postedShipmentNo.'));
        Parameters.Add(Contract.Parameter('loanerNo', 'string', false, 'Loaner number, at most 20 characters. May be used alone.'));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success after the loan has been closed.'));
        Fields.Add(Contract.ResponseField('loanerNo', 'string', 'Received loaner number.'));
        Fields.Add(Contract.ResponseField('loanerEntryNo', 'integer', 'Closed loan history entry number.'));
        Fields.Add(Contract.ResponseField('documentType', 'string', 'Invariant document kind: Quote or Order.'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'Original service document number.'));
        Fields.Add(Contract.ResponseField('serviceItemLineNo', 'integer', 'Original service item line number.'));
        Fields.Add(Contract.ResponseField('dateReceived', 'string', 'Date the loaner was received, in ISO format.'));
        Fields.Add(Contract.ResponseField('timeReceived', 'string', 'Time the loaner was received, in ISO format.'));
        Fields.Add(Contract.ResponseField('lent', 'boolean', 'False after successful receipt.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No complete identifier set was supplied.', 'Send documentNo with serviceItemLineNo, postedShipmentNo with lineNo, or loanerNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier has an invalid type or length.', 'Send nonempty strings of at most 20 characters and positive integer line numbers.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter was supplied.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The loaner or document line does not exist.', 'Read the available loaners and lines with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different loans.', 'Send identifiers for the same loaner and document line.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'There is no open loan for this identifier.', 'Check the loaner is lent on the selected document before receiving it.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot receive loaners.', 'Ask an administrator for full Bifrost access and native service data permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the operation; its error text is returned.', 'Correct the Business Central error and retry.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Closes the open loan history entry and clears the loaner number from related order and shipment lines.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST SvcFull ori');
        Effect.Add('preconditions', 'An existing loaner currently lent on the selected document. Repeating receipt is refused.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read loaner availability and loan history.'));
        Related.Add(Contract.RelatedEntry('Service.Loaner.Lend', 'Lend an available loaner on a service order item line.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Post', 'Post the service order when repair work is complete.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow.Add('steps', 'Use Service.Loaner.Lend to lend a loaner on a service order item line. Receive the returned loaner with Service.Loaner.Receive, then read its availability.');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Request: JsonObject;
    begin
        Example.Add('description', 'Receive a loaner by its number.');
        Example.Add('type', 'Service.Loaner.Receive');
        Request.Add('loanerNo', 'XLOANER');
        Example.Add('data', Request);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains the loaner scope and transaction semantics.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Use Service.Loaner.Lend to lend a loaner on a service order item line. Receipt preserves loan history and makes the loaner available again. No expectedCount is needed. Omit Commit keeps the caller transaction. Every supplied identifier must refer to the same loan.';
        exit(true);
    end;

    /// <summary>Summarizes the resulting loaner state.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Receives a loaner through the normal Business Central operation and returns the closed loan identity, received date and time, and lent=false.';
        exit(true);
    end;
}
