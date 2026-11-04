namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>Converts a service quote through the standard Business Central conversion.</summary>
codeunit 10076051 "Svc Quote MakeOrder Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Validates the quote, commits, confirms its count and runs native BC conversion.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        OrderHeader: Record "Service Header";
        Lookup: Codeunit "Svc Document Lookup ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        ConvertQuote: Codeunit "Service-Quote to Order";
        WriteCheck: Codeunit "Svc Write Check ori";
        Response: JsonObject;
        QuoteNo: Code[20];
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Quote.MakeOrder');
        if not Lookup.FindDocument(Argument, "Service Document Type"::Quote, Header) then
            exit;
        if not CheckPreconditions(Argument, Header) then
            exit;
        QuoteNo := Header."No.";
        Commit();
        if not ConfirmGate.Check(Argument, Argument.Type) then
            exit;
        // Confirmation locks and re-resolves the quote after Commit. Do not convert a stale buffer.
        if not Lookup.FindDocument(Argument, "Service Document Type"::Quote, Header) then
            exit;
        if not CheckPreconditions(Argument, Header) then
            exit;
        ClearLastError();
        if not ConvertQuote.Run(Header) then begin
            Argument.RespondWithLastError();
            exit;
        end;
        OrderHeader.Get("Service Document Type"::Order, ConvertQuote.ReturnOrderNo());
        BuildResponse(QuoteNo, OrderHeader, Response);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Checks the caller's base service table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        HeaderRef: RecordRef;
    begin
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
        DescriptionLbl: Label 'Converts a service quote into a service order, as the Make Order action on the quote does. The quote is removed. Commits and cannot be undone.', Comment = 'is-IS=Breytir þjónustutilboði í þjónustupöntun, eins og aðgerðin Gera pöntun á tilboðinu. Tilboðinu er eytt. Framkvæmir Commit og ekki er hægt að afturkalla.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'service quote to order, make service order, customer accepted the service quote', Comment = 'is-IS=þjónustutilboð í pöntun, gera þjónustupöntun, viðskiptamaður samþykkti þjónustutilboðið';
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
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetIdentityParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Name: Text;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        foreach Name in 'quoteNo,orderNo,orderSystemId,customerNo,customerName,orderDate,nextStep'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'string', 'Converted quote and new order identity or next operation.'));
        foreach Name in 'serviceItemLines,serviceLines,allocationsToReallocate'.Split(',') do
            Fields.Add(Contract.ResponseField(Name, 'integer', 'Count on the new order.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parts.GetIdentityErrors(Errors);
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The quote needs a Customer No., Bill-to Customer No. and Service Order Nos. setup.', 'Set the missing field and send the request again.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused conversion; its own error text is returned. Nothing was changed.', 'Correct the BC error before retrying.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Deletes the service quote and creates a service order through Service-Quote to Order. This call commits.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Svc ori');
        Effect.Add('preconditions', 'A quote with Customer No. and Bill-to Customer No.; configured Service Order Nos.; BC accepts the conversion.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Sales.Quote.MakeOrder', 'Use for a sales quote.'));
        Related.Add(Contract.RelatedEntry('Service.Allocation.Allocate', 'Reallocate moved allocations marked Reallocation Needed.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Release', 'Release the new order.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Post', 'Post the new order.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetServiceWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Convert an accepted quote', '{"type":"Service.Quote.MakeOrder","data":{"no":"SQ000001","expectedCount":1}}', '{"status":"Success","quoteNo":"SQ000001","orderNo":"SO000001"}'));
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains the order-only scope and transaction semantics.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'This call commits, including when Omit Commit is requested. Not retry-safe: the deleted quote answers RecordNotFound after success. Quote fields remain editable through Data.Records.Set because conversion owns no field end to end. Contract quotes, archiving, loaners and optional chaining are outside scope.';
        exit(true);
    end;

    /// <summary>Summarizes the resulting service order state.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Converts an accepted service quote through Service-Quote to Order (5923), without Yes/No UI. The response counts the new order rows and identifies the next allocation, release or posting step. This call commits.';
        exit(true);
    end;
    local procedure CheckPreconditions(var Argument: Record "Message Argument ori"; Header: Record "Service Header"): Boolean
    var
        Setup: Record "Service Mgt. Setup";
        CustomerLbl: Label 'Service quote %1 has no customer. Nothing was changed.', Comment = '%1 = quote number, is-IS=Þjónustutilboð %1 hefur engan viðskiptamann. Engu var breytt.';
        BillToLbl: Label 'Service quote %1 has no bill-to customer. Nothing was changed.', Comment = '%1 = quote number, is-IS=Þjónustutilboð %1 hefur engan greiðanda. Engu var breytt.';
        CustomerNextLbl: Label 'Set Customer No. with Data.Records.Set and send the request again.', Comment = 'is-IS=Settu Customer No. með Data.Records.Set og sendu beiðnina aftur.';
        BillToNextLbl: Label 'Set Bill-to Customer No. with Data.Records.Set and send the request again.', Comment = 'is-IS=Settu Bill-to Customer No. með Data.Records.Set og sendu beiðnina aftur.';
        SeriesNextLbl: Label 'Set Service Order Nos. in Service Mgt. Setup.', Comment = 'is-IS=Settu Service Order Nos. í Service Mgt. Setup.';
    begin
        if Header."Customer No." = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CustomerLbl, Header."No."), 'Customer No.', '', '', CustomerNextLbl);
            exit(false);
        end;
        if Header."Bill-to Customer No." = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(BillToLbl, Header."No."), 'Bill-to Customer No.', '', '', BillToNextLbl);
            exit(false);
        end;
        ClearLastError();
        if not CheckOrderSeries(Setup) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'Service Order Nos.', '', '', SeriesNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure CheckOrderSeries(var Setup: Record "Service Mgt. Setup")
    begin
        Setup.Get();
        Setup.TestField("Service Order Nos.");
    end;

    local procedure BuildResponse(QuoteNo: Code[20]; Header: Record "Service Header"; var Response: JsonObject)
    var
        ItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        Allocation: Record "Service Order Allocation";
        ReallocateCount: Integer;
        ReallocateLbl: Label 'The order has %1 allocations that need a resource again. Use Service.Allocation.Allocate.', Comment = '%1 = allocation count, is-IS=Pöntunin er með %1 úthlutanir sem þurfa forða aftur. Notaðu Service.Allocation.Allocate.';
        NextLbl: Label 'Use Service.Order.Release, then Service.Order.Post.', Comment = 'is-IS=Notaðu Service.Order.Release og síðan Service.Order.Post.';
    begin
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ServiceLine.SetRange("Document Type", Header."Document Type");
        ServiceLine.SetRange("Document No.", Header."No.");
        Allocation.SetRange("Document Type", Header."Document Type");
        Allocation.SetRange("Document No.", Header."No.");
        Allocation.SetRange(Status, Allocation.Status::"Reallocation Needed");
        ReallocateCount := Allocation.Count();
        Response.Add('status', 'Success');
        Response.Add('quoteNo', QuoteNo);
        Response.Add('orderNo', Header."No.");
        Response.Add('orderSystemId', Format(Header.SystemId, 0, 4));
        Response.Add('customerNo', Header."Customer No.");
        Response.Add('customerName', Header.Name);
        Response.Add('orderDate', Format(Header."Order Date", 0, 9));
        Response.Add('serviceItemLines', ItemLine.Count());
        Response.Add('serviceLines', ServiceLine.Count());
        Response.Add('allocationsToReallocate', ReallocateCount);
        if ReallocateCount > 0 then
            Response.Add('nextStep', StrSubstNo(ReallocateLbl, ReallocateCount))
        else
            Response.Add('nextStep', NextLbl);
    end;
}
