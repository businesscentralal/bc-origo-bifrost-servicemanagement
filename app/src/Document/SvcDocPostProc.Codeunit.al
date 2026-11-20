namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.Receivables;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Posting;
using Origo.Bifrost;

/// <summary>Validates and posts one standalone service document in the native transaction.</summary>
codeunit 10076095 "Svc Doc Post Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Invoice: Record "Service Invoice Header";
        Credit: Record "Service Cr.Memo Header";
        Request: Codeunit "Svc Doc Request ori";
        Gate: Codeunit "Svc Posting Gate ori";
        Options: Codeunit "Svc Post Options ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        ServicePost: Codeunit "Service-Post";
        Response: JsonObject;
        Number: Code[20];
        IsInvoice: Boolean;
        PostedDocument: Variant;
    begin
        Rec.AssertIsLicensed();
        Rec.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Document.Post');
        if not Gate.AssertCanPost(Rec) then
            exit;
        Header.LockTable();
        Line.LockTable();
        if not Request.Find(Rec, Header) then
            exit;
        if not Options.CheckPolicy(Rec, true, false, true) then
            exit;
        if not ConfirmGate.Check(Rec, Rec.Type) then
            exit;
        Number := Header."No.";
        IsInvoice := Header."Document Type" = Header."Document Type"::Invoice;
        Response.Add('documentNo', Number);
        Response.Add('customerNo', Header."Customer No.");
        ServicePost.SetHideValidationDialog(true);
        // Native initialization derives the options from Invoice/Credit Memo after loading lines.
        // Pre-setting Invoice would filter unshipped credit memo lines out before that step.
        ServicePost.SetPostingOptions(false, false, false);
        ServicePost.Run(Header);
        ServicePost.GetPostedDocumentRecord(Header, PostedDocument);
        if IsInvoice then begin
            Invoice := PostedDocument;
            Invoice.CalcFields(Amount, "Amount Including VAT");
            AddPosted(Response, 'Invoice', Invoice."No.", Invoice.SystemId, Invoice.Amount, Invoice."Amount Including VAT", Invoice."Bill-to Customer No.", Invoice."Source Code");
        end else begin
            Credit := PostedDocument;
            Credit.CalcFields(Amount, "Amount Including VAT");
            AddPosted(Response, 'CreditMemo', Credit."No.", Credit.SystemId, Credit.Amount, Credit."Amount Including VAT", Credit."Bill-to Customer No.", Credit."Source Code");
        end;
        Response.Add('status', 'Success');
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure AddPosted(var Response: JsonObject; TypeName: Text; Number: Code[20]; Id: Guid; Amount: Decimal; AmountWithVAT: Decimal; BillToCustomerNo: Code[20]; SourceCode: Code[10])
    var
        CustomerEntry: Record "Cust. Ledger Entry";
        GLEntry: Record "G/L Entry";
        Ranges: JsonObject;
    begin
        Response.Add('documentType', TypeName);
        Response.Add('postedDocumentNo', Number);
        Response.Add('systemId', Format(Id, 0, 4));
        Response.Add('amount', Amount);
        Response.Add('amountIncludingVAT', AmountWithVAT);
        CustomerEntry.ReadIsolation(IsolationLevel::ReadCommitted);
        CustomerEntry.SetRange("Document No.", Number);
        CustomerEntry.SetRange("Customer No.", BillToCustomerNo);
        CustomerEntry.SetRange("Source Code", SourceCode);
        if TypeName = 'Invoice' then
            CustomerEntry.SetRange("Document Type", CustomerEntry."Document Type"::Invoice)
        else
            CustomerEntry.SetRange("Document Type", CustomerEntry."Document Type"::"Credit Memo");
        CustomerEntry.SetLoadFields("Entry No.", "Transaction No.");
        CustomerEntry.FindLast();
        Ranges.Add('customerFirst', CustomerEntry."Entry No.");
        Ranges.Add('customerLast', CustomerEntry."Entry No.");
        GLEntry.ReadIsolation(IsolationLevel::ReadCommitted);
        GLEntry.SetRange("Transaction No.", CustomerEntry."Transaction No.");
        GLEntry.SetLoadFields("Entry No.");
        if GLEntry.FindFirst() then
            Ranges.Add('glFirst', GLEntry."Entry No.");
        if GLEntry.FindLast() then
            Ranges.Add('glLast', GLEntry."Entry No.");
        Response.Add('entryRanges', Ranges);
    end;
}
