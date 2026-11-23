namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;

/// <summary>Applies caller invoice choices only while bound to one native contract operation.</summary>
codeunit 10076157 "Svc Contract Options ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        CreateInvoice: Boolean;
        InvoiceNo: Code[20];

    /// <summary>Sets the explicit invoice choice before binding.</summary>
    internal procedure SetCreateInvoice(Value: Boolean)
    begin
        CreateInvoice := Value;
        Clear(InvoiceNo);
    end;

    /// <summary>Returns the invoice created by this operation, not an earlier invoice.</summary>
    internal procedure GetInvoiceNo(): Code[20]
    begin
        exit(InvoiceNo);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::SignServContractDoc, OnAfterSetInvoicing, '', false, false)]
    local procedure ApplyInvoiceChoice(var ServiceContractHeader: Record "Service Contract Header"; var InvoiceNow: Boolean; var InvoiceFrom: Date; var InvoiceTo: Date; var InvoicingStartingPeriod: Boolean; var GoOut: Boolean; HideDialog: Boolean)
    begin
        if not CreateInvoice then
            InvoiceNow := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::SignServContractDoc, OnAfterCreateServiceLinesLedgerEntries, '', false, false)]
    local procedure CaptureInvoice(var ServiceHeader: Record "Service Header"; ServiceContractHeader: Record "Service Contract Header")
    begin
        InvoiceNo := ServiceHeader."No.";
    end;
}
