namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Runs bounded native contract reports and non-deleting line credits in one transaction.</summary>
codeunit 10076168 "Svc Contr Jobs ori"
{
    Access = Internal;

    /// <summary>Revalidates and locks the scope, executes native jobs and returns their actual output.</summary>
    [CommitBehavior(CommitBehavior::Error)]
    internal procedure Run(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Contract Header";
        InvoiceReport: Report "Create Contract Invoices";
        OrderReport: Report "Create Contract Service Orders";
        Scope: Codeunit "Svc Contr Job Scope ori";
        Events: Codeunit "Svc Contr Job Events ori";
        Contracts: List of [Code[20]];
        Number: Code[20];
        FromDate: Date;
        ToDate: Date;
        BeforeCount: Integer;
        Response: JsonObject;
        Processed: JsonArray;
        Skipped: JsonArray;
        CreditMemos: JsonArray;
        Skip: JsonObject;
        SkipLbl: Label 'No eligible invoice period or service item line was due in the selected dates.', Comment = 'is-IS=Ekkert gjaldgengt reikningstímabil eða þjónustuvörulína var á gjalddaga á völdum dagsetningum.';
        NextLbl: Label 'Review the created documents. Post invoices and credit memos separately with Service.Document.Post after review.', Comment = 'is-IS=Yfirfarðu stofnuð skjöl. Bókaðu reikninga og kreditreikninga sérstaklega með Service.Document.Post að yfirferð lokinni.';
    begin
        if not Scope.Resolve(Argument, Contracts, FromDate, ToDate, true) then
            exit;
        BindSubscription(Events);
        foreach Number in Contracts do begin
            Header.Get(Header."Contract Type"::Contract, Number);
            Header.SetRecFilter();
            BeforeCount := Events.OutputCount();
            case Argument.Type of
                Argument.Type::"Service.Contract.CreateInvoices":
                    begin
                        Clear(InvoiceReport);
                        InvoiceReport.SetTableView(Header);
                        InvoiceReport.SetOptions(FromDate, ToDate, 0);
                        InvoiceReport.SetHideDialog(true);
                        InvoiceReport.UseRequestPage(false);
                        InvoiceReport.RunModal();
                    end;
                Argument.Type::"Service.Contract.CreateServiceOrders":
                    begin
                        Clear(OrderReport);
                        OrderReport.SetTableView(Header);
                        OrderReport.InitializeRequest(FromDate, ToDate, 0);
                        OrderReport.SetHideDialog(true);
                        OrderReport.UseRequestPage(false);
                        OrderReport.RunModal();
                    end;
                Argument.Type::"Service.Contract.CreateCreditMemo":
                    CreateCredits(Header, ToDate, CreditMemos);
            end;
            Processed.Add(Number);
            if (Argument.Type <> Argument.Type::"Service.Contract.CreateCreditMemo") and (BeforeCount = Events.OutputCount()) then begin
                Clear(Skip);
                Skip.Add('contractNo', Number);
                Skip.Add('reason', SkipLbl);
                Skipped.Add(Skip);
            end;
            Header.Reset();
        end;
        UnbindSubscription(Events);
        Response.Add('status', 'Success');
        Response.Add('count', Contracts.Count());
        Response.Add('contractsProcessed', Processed);
        Response.Add('contractsSkipped', Skipped);
        Events.AddResponse(Response);
        Response.Add('creditMemos', CreditMemos);
        Response.Add('nextStep', NextLbl);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CreateCredits(Header: Record "Service Contract Header"; DateTo: Date; var CreditMemos: JsonArray)
    var
        Line: Record "Service Contract Line";
        Management: Codeunit ServContractManagement;
        Entry: JsonObject;
        CreditNo: Code[20];
    begin
        // Full records: the standard non-deleting operation marks successfully credited lines.
        Line.ReadIsolation := IsolationLevel::UpdLock;
        Line.SetRange("Contract Type", Header."Contract Type");
        Line.SetRange("Contract No.", Header."Contract No.");
        Line.SetRange(Credited, false);
        Line.SetFilter("Credit Memo Date", '<>%1&<=%2', 0D, DateTo);
        if Line.FindSet(true) then
            repeat
                Clear(Management);
                Management.InitCodeUnit();
                CreditNo := Management.CreateContractLineCreditMemo(Line, false);
                Management.FinishCodeunit();
                if CreditNo <> '' then begin
                    Clear(Entry);
                    Entry.Add('no', CreditNo);
                    Entry.Add('contractNo', Header."Contract No.");
                    Entry.Add('lineNo', Line."Line No.");
                    CreditMemos.Add(Entry);
                end;
            until Line.Next() = 0;
    end;
}
