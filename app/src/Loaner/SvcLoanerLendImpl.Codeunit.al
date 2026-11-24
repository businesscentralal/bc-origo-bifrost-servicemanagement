namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Implements Service.Loaner.Lend through the standard Business Central loaner lifecycle.</summary>
codeunit 10076107 "Svc Loaner Lend Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        Processor: Codeunit "Svc Loaner Lend Proc ori";
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
        exit(Database::"Service Item Line");
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Lends an available loaner on a service order item line and creates its loan history.', Comment = 'is-IS=Lánar tiltækt lánstæki á þjónustupöntunarlínu og skráir lánasögu þess.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'lend loaner, issue loaner, replacement during repair', Comment = 'is-IS=lána lánstæki, afhenda lánstæki, staðgengill meðan á viðgerð stendur';
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
        Target.Add(Contract.TargetEntry('data.documentNo + data.serviceItemLineNo', 'order line', 'The service order item line receiving the loaner.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'The service item line GUID; all identifiers must identify the same order line.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Service order number, at most 20 characters; requires serviceItemLineNo.'));
        Parameters.Add(Contract.Parameter('serviceItemLineNo', 'integer', false, 'Positive service item line number; requires documentNo.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty service item line GUID, as an alternative to the order number and line number.'));
        Parameters.Add(Contract.Parameter('loanerNo', 'string', true, 'Available loaner number, at most 20 characters.'));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success after the loan has been opened.'));
        Fields.Add(Contract.ResponseField('loanerNo', 'string', 'Lent loaner number.'));
        Fields.Add(Contract.ResponseField('loanerEntryNo', 'integer', 'New loan history entry number.'));
        Fields.Add(Contract.ResponseField('documentType', 'string', 'Invariant document kind: Quote or Order.'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'Original service document number.'));
        Fields.Add(Contract.ResponseField('serviceItemLineNo', 'integer', 'Original service item line number.'));
        Fields.Add(Contract.ResponseField('systemId', 'string', 'Service item line GUID.'));
        Fields.Add(Contract.ResponseField('dateLent', 'string', 'Date the loaner was lent, in ISO format.'));
        Fields.Add(Contract.ResponseField('timeLent', 'string', 'Time the loaner was lent, in ISO format.'));
        Fields.Add(Contract.ResponseField('lent', 'boolean', 'True after successful lending.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No complete identifier set was supplied.', 'Send loanerNo and either documentNo with serviceItemLineNo, or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier has an invalid type or length.', 'Send nonempty strings of at most 20 characters and positive integer line numbers.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter was supplied.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The loaner or document line does not exist.', 'Read the available loaners and lines with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different loans.', 'Send identifiers for the same loaner and document line.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The loaner is blocked or already lent, or the line already has a loaner.', 'Choose an available loaner and receive any current loan with Service.Loaner.Receive.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot lend loaners.', 'Ask an administrator for full Bifrost access and native service data permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the operation; its error text is returned.', 'Correct the Business Central error and retry.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates an open loan history entry and sets the loaner number on the service order item line.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST SvcFull ori');
        Effect.Add('preconditions', 'An available, unblocked loaner and a service order item line with no current loaner.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read available loaners and service order item lines.'));
        Related.Add(Contract.RelatedEntry('Service.Loaner.Receive', 'Receive the loaner when it is returned.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow.Add('steps', 'Read available loaners and the service order item line. Lend with Service.Loaner.Lend; use Service.Loaner.Receive when it is returned.');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Request: JsonObject;
    begin
        Example.Add('description', 'Lend an available loaner on an order item line.');
        Example.Add('type', 'Service.Loaner.Lend');
        Request.Add('documentNo', 'XORDER');
        Request.Add('serviceItemLineNo', 10000);
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
        Notes := 'Use Service.Loaner.Lend to lend and Service.Loaner.Receive to receive. Generic field writes cannot change the loaner number. No expectedCount is needed. Omit Commit keeps the caller transaction. Every supplied identifier must identify the same order line.';
        exit(true);
    end;

    /// <summary>Summarizes the resulting loaner state.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Lends an available loaner through the normal Business Central operation and returns its loan history entry, lent date and time, and lent=true.';
        exit(true);
    end;
}
