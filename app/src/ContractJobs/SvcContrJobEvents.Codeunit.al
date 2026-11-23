namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;

/// <summary>Collects only documents and item lines emitted by the current bound report run.</summary>
codeunit 10076169 "Svc Contr Job Events ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        Invoices: JsonArray;
        Orders: JsonArray;
        AddedLines: JsonArray;
        NewOrders: List of [Code[20]];

    /// <summary>Adds the observed output to the response after the native reports succeed.</summary>
    internal procedure AddResponse(var Response: JsonObject)
    begin
        Response.Add('invoicesCreated', Invoices);
        Response.Add('serviceOrdersCreated', Orders);
        Response.Add('linesAddedToExistingOrders', AddedLines);
    end;

    /// <summary>Returns the number of documents or item lines emitted so far.</summary>
    internal procedure OutputCount(): Integer
    begin
        exit(Invoices.Count() + Orders.Count() + AddedLines.Count());
    end;

    [EventSubscriber(ObjectType::Report, Report::"Create Contract Invoices", 'OnAfterServiceContractHeaderOnAfterGetRecord', '', false, false)]
    local procedure InvoiceCreated(var ServiceContractHeader: Record "Service Contract Header"; InvoiceNo: Code[20])
    var
        Invoice: Record "Service Header";
        Entry: JsonObject;
    begin
        if InvoiceNo = '' then
            exit;
        Invoice.Get(Invoice."Document Type"::Invoice, InvoiceNo);
        Invoice.CalcFields(Amount);
        Entry.Add('no', InvoiceNo);
        Entry.Add('contractNo', ServiceContractHeader."Contract No.");
        Entry.Add('customerNo', Invoice."Customer No.");
        Entry.Add('amount', Invoice.Amount);
        Invoices.Add(Entry);
    end;

    [EventSubscriber(ObjectType::Report, Report::"Create Contract Service Orders", 'OnAfterCreateServiceHeader', '', false, false)]
    local procedure OrderCreated(var ServiceHeader: Record "Service Header"; ServiceContractHeader: Record "Service Contract Header")
    begin
        NewOrders.Add(ServiceHeader."No.");
    end;

    [EventSubscriber(ObjectType::Report, Report::"Create Contract Service Orders", 'OnAfterInsertServItemLine', '', false, false)]
    local procedure ItemLineCreated(var ServiceItemLine: Record "Service Item Line"; ServiceContractLine: Record "Service Contract Line")
    var
        Entry: JsonObject;
    begin
        Entry.Add('no', ServiceItemLine."Document No.");
        Entry.Add('contractNo', ServiceContractLine."Contract No.");
        Entry.Add('serviceItemNo', ServiceItemLine."Service Item No.");
        Entry.Add('lineNo', ServiceItemLine."Line No.");
        if NewOrders.Contains(ServiceItemLine."Document No.") then
            Orders.Add(Entry)
        else
            AddedLines.Add(Entry);
    end;
}
