namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.Posting;
using Origo.Bifrost;

/// <summary>Implements Service.Order.Post through the standard Business Central service posting.</summary>
codeunit 10076079 "Svc Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Validates the request, confirms the count, then posts the order. This call commits.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        Lookup: Codeunit "Svc Document Lookup ori";
        Options: Codeunit "Svc Post Options ori";
        Gate: Codeunit "Svc Posting Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        ServicePost: Codeunit "Service-Post";
        Shipments: List of [Code[20]];
        Invoices: List of [Code[20]];
        Response: JsonObject;
        Ship: Boolean;
        Consume: Boolean;
        Invoice: Boolean;
        AnySent: Boolean;
        OrderNo: Code[20];
        LastLedgerEntryNo: Integer;
        PostNextLbl: Label 'Correct the setup or document named by Business Central and send the posting again. Nothing was posted.', Comment = 'is-IS=Leiðréttu uppsetninguna eða skjalið sem Business Central nefnir og sendu bókunina aftur. Ekkert var bókað.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Order.Post');
        if not Gate.AssertCanPost(Argument) then
            exit;
        Options.ReadFlags(Argument, Ship, Consume, Invoice, AnySent);
        if not Lookup.FindDocument(Argument, "Service Document Type"::Order, Header) then
            exit;
        if not Options.Resolve(Argument, Ship, Consume, Invoice, AnySent) then
            exit;
        if not Options.CheckSomethingToPost(Argument, Header, Ship, Consume, Invoice) then
            exit;
        OrderNo := Header."No.";
        Options.CapturePosted(OrderNo, Shipments, Invoices, LastLedgerEntryNo);
        // Service-Post ends in Commit() and Codeunit.Run needs a clean transaction, as in Sales.Document.Post.
        Commit();
        if not ConfirmGate.Check(Argument, Argument.Type) then
            exit;
        if not Header.Get("Service Document Type"::Order, OrderNo) then
            exit;
        Argument.SetErrorContext('no', '', PostNextLbl);
        ClearLastError();
        ServicePost.SetPostingOptions(Ship, Consume, Invoice);
        ServicePost.SetHideValidationDialog(true);
        if not ServicePost.Run(Header) then begin
            Argument.RespondWithLastError();
            exit;
        end;
        Argument.ClearErrorContext();
        BuildResponse(Options, OrderNo, Shipments, Invoices, LastLedgerEntryNo, Ship, Consume, Invoice, Response);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildResponse(Options: Codeunit "Svc Post Options ori"; OrderNo: Code[20]; Shipments: List of [Code[20]]; Invoices: List of [Code[20]]; LastLedgerEntryNo: Integer; Ship: Boolean; Consume: Boolean; Invoice: Boolean; var Response: JsonObject)
    var
        Header: Record "Service Header";
        Posted: JsonArray;
        Lines: JsonArray;
        Deleted: Boolean;
    begin
        Deleted := not Header.Get("Service Document Type"::Order, OrderNo);
        Response.Add('status', 'Success');
        Response.Add('documentNo', OrderNo);
        if not Deleted then begin
            Response.Add('customerNo', Header."Customer No.");
            Response.Add('customerName', Header.Name);
        end;
        Response.Add('ship', Ship);
        Response.Add('consume', Consume);
        Response.Add('invoice', Invoice);
        Options.CollectPosted(OrderNo, Shipments, Invoices, Posted);
        Response.Add('postedDocuments', Posted);
        Response.Add('serviceLedgerEntries', Options.CountLedgerEntries(OrderNo, LastLedgerEntryNo));
        Response.Add('orderDeleted', Deleted);
        if not Deleted then
            Options.BuildLines(Header, Lines);
        Response.Add('lines', Lines);
    end;

    /// <summary>Lists the type only for callers holding the posting token and write permission on service headers.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Svc Posting Gate ori";
        HeaderRef: RecordRef;
    begin
        if not Gate.HasPostingPermission() then
            exit(false);
        HeaderRef.Open(Database::"Service Header");
        exit(HeaderRef.WritePermission());
    end;

    /// <summary>Returns the service header filter scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Header");
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Posts a service order: ships, consumes or invoices the quantities on its lines with the standard Business Central service posting. Commits and cannot be undone.', Comment = 'is-IS=Bókar þjónustupöntun: afhendir, notar eða reikningsfærir magnið á línum hennar með venjulegri þjónustubókun Business Central. Framkvæmir Commit og ekki er hægt að afturkalla.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post service order, ship and invoice, consume, invoice the service job, ship service items', Comment = 'is-IS=bóka þjónustupöntun, afhenda og reikningsfæra, nota, reikningsfæra þjónustuverkið, afhenda þjónustuvörur';
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
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetTarget(Target);
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Posted: JsonObject;
        PostedFields: JsonArray;
        LineObject: JsonObject;
        LineFields: JsonArray;
        Name: Text;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        foreach Name in 'documentNo,customerNo,customerName'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'string', 'The service order that was posted.'));
        foreach Name in 'ship,consume,invoice,orderDeleted'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'boolean', 'The options posted, and whether Business Central removed the fully posted order.'));
        Fields.Add(Contract.ResponseField('serviceLedgerEntries', 'integer', 'Service ledger entries created by this call.'));
        foreach Name in 'type,no,recordSystemId,postingDate'.Split(',') do
            PostedFields.Add(Contract.ResponseField(Name, 'string', 'Service Shipment or Service Invoice created by this call.'));
        PostedFields.Add(Contract.ResponseField('amount', 'number', 'Invoices only.'));
        PostedFields.Add(Contract.ResponseField('amountIncludingVAT', 'number', 'Invoices only.'));
        PostedFields.Add(Contract.ResponseField('custLedgerEntryNo', 'integer', 'Invoices only.'));
        Posted := Contract.ResponseField('postedDocuments', 'array', 'The posted documents this call created.');
        Posted.Add('children', PostedFields);
        Fields.Add(Posted);
        foreach Name in 'lineNo,quantity,quantityShipped,quantityConsumed,quantityInvoiced'.Split(',') do
            LineFields.Add(Contract.ResponseField(Name, 'number', 'Quantities on the remaining order line.'));
        LineFields.Add(Contract.ResponseField('type', 'string', 'Line type.'));
        LineFields.Add(Contract.ResponseField('no', 'string', 'Line number of the item, resource or cost.'));
        LineObject := Contract.ResponseField('lines', 'array', 'Remaining order lines; empty when the order was deleted.');
        LineObject.Add('children', LineFields);
        Fields.Add(LineObject);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetErrors(Errors, false);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Posts the service order through Service-Post: shipments, consumption and invoices are created, ledger entries are written and a fully posted order is deleted. This call commits and cannot be undone.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST SvcPost ori');
        Effect.Add('preconditions', 'Quantities on the lines (Qty. to Ship, Qty. to Consume, Qty. to Invoice); posting setup; a service invoice posting policy that allows the combination.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetRelated(Related, false);
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.GetWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Svc Post Contract ori";
    begin
        Contract.PostExamples(Examples);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains commit behavior and not retry-safe semantics.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'This call commits, including when Omit Commit is requested; Business Central''s own commit in Service-Post is kept. Not retry-safe: after success the posted quantities are gone and a fully posted order is deleted. Stand-alone service invoices and credit memos, batch posting, post and print or send, and undo are out of scope. Set the posting date and quantities on the order with Data.Records.Set before posting; the posted-quantity fields themselves are refused there.';
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Posts a service order with the standard Business Central service posting: ship, ship and consume, ship and invoice, or invoice what was shipped. Send expectedCount 1. This call commits.';
        exit(true);
    end;
}
