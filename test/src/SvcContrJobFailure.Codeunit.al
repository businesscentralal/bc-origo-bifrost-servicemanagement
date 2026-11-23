namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Raises late native errors to verify full rollback of periodic operations.</summary>
codeunit 97789 "Svc Contr Job Failure ori"
{
    EventSubscriberInstance = Manual;

    var
        Request: JsonObject;
        TypeValue: Enum "Message Type ori";

    trigger OnRun()
    var
        Data: Codeunit "Svc Test Data ori";
        Response: JsonObject;
        TextValue: Text;
    begin
        Response := Data.Invoke(TypeValue, Request, '', 1033, true);
        if Data.TextValue(Response, 'status') <> 'Success' then begin
            Response.WriteTo(TextValue);
            Error(TextValue);
        end;
        Error('X25-EXPECTED-CALLER-ROLLBACK');
    end;

    /// <summary>Configures an unbound caller rollback probe; event failure subscribers are not bound.</summary>
    procedure SetRequest(NewType: Enum "Message Type ori"; NewRequest: JsonObject)
    begin
        TypeValue := NewType;
        Request := NewRequest;
    end;


    [EventSubscriber(ObjectType::Report, Report::"Create Contract Invoices", 'OnAfterServiceContractHeaderOnAfterGetRecord', '', false, false)]
    local procedure FailInvoice(var ServiceContractHeader: Record "Service Contract Header"; InvoiceNo: Code[20])
    begin
        Error('X-owned late invoice failure.');
    end;

    [EventSubscriber(ObjectType::Report, Report::"Create Contract Service Orders", 'OnAfterInsertServItemLine', '', false, false)]
    local procedure FailOrder(var ServiceItemLine: Record "Service Item Line"; ServiceContractLine: Record "Service Contract Line")
    begin
        Error('X-owned late order failure.');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ServContractManagement, 'OnAfterCreateContractLineCreditMemo', '', false, false)]
    local procedure FailCredit(var ServiceContractLine: Record "Service Contract Line"; ServiceCreditMemoNo: Code[20])
    begin
        Error('X-owned late credit failure.');
    end;
}
