namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.Posting;
using Origo.Bifrost;

/// <summary>Locks, confirms and posts within one error boundary, retaining standard Business Central commits.</summary>
codeunit 10076080 "Svc Order Post Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecutePosting(Rec);
    end;

    local procedure ExecutePosting(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
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
        CustomerNo: Code[20];
        CustomerName: Text[100];
        LastLedgerEntryNo: Integer;
        PostNextLbl: Label 'Correct the setup or document named by Business Central and send the posting again. Nothing was posted.', Comment = 'is-IS=Leiðréttu uppsetninguna eða skjalið sem Business Central nefnir og sendu bókunina aftur. Ekkert var bókað.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Order.Post');
        if not Gate.AssertCanPost(Argument) then
            exit;
        Header.LockTable();
        Line.LockTable();
        Options.ReadFlags(Argument, Ship, Consume, Invoice, AnySent);
        if not Lookup.FindDocument(Argument, "Service Document Type"::Order, Header) then
            exit;
        if Options.RespondBadFlags(Argument) then
            exit;
        if not Options.Resolve(Argument, Ship, Consume, Invoice, AnySent) then
            exit;
        if not Options.CheckSomethingToPost(Argument, Header, Ship, Consume, Invoice) then
            exit;
        OrderNo := Header."No.";
        CustomerNo := Header."Customer No.";
        CustomerName := Header.Name;
        Options.CapturePosted(OrderNo, Shipments, Invoices, LastLedgerEntryNo);
        if not ConfirmGate.Check(Argument, Argument.Type) then
            exit;
        if not Header.Get("Service Document Type"::Order, OrderNo) then
            exit;
        Argument.SetErrorContext('no', '', PostNextLbl);
        ClearLastError();
        ServicePost.SetPostingOptions(Ship, Consume, Invoice);
        ServicePost.SetHideValidationDialog(true);
        // Do not consume the Boolean: this retains our locks through the standard posting transaction.
        // The outer processor boundary catches BC errors; only Service-Post owns the commits.
        ServicePost.Run(Header);
        Argument.ClearErrorContext();
        BuildResponse(Options, OrderNo, CustomerNo, CustomerName, Shipments, Invoices, LastLedgerEntryNo, Ship, Consume, Invoice, Response);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildResponse(Options: Codeunit "Svc Post Options ori"; OrderNo: Code[20]; CustomerNo: Code[20]; CustomerName: Text[100]; Shipments: List of [Code[20]]; Invoices: List of [Code[20]]; LastLedgerEntryNo: Integer; Ship: Boolean; Consume: Boolean; Invoice: Boolean; var Response: JsonObject)
    var
        Header: Record "Service Header";
        Posted: JsonArray;
        Lines: JsonArray;
        Deleted: Boolean;
    begin
        Deleted := not Header.Get("Service Document Type"::Order, OrderNo);
        Response.Add('status', 'Success');
        Response.Add('documentNo', OrderNo);
        Response.Add('customerNo', CustomerNo);
        Response.Add('customerName', CustomerName);
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

}
