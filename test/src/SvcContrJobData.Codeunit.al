namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Microsoft.Service.Document;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>Creates raw owned signed contracts and restores every setup value changed by the periodic jobs.</summary>
codeunit 97784 "Svc Contr Job Data ori"
{
    var
        PriorSetup: Record "Service Mgt. Setup";
        BaseFixture: Codeunit "Svc Contract Data ori";
        Snapshotted: Boolean;
        Contracts: List of [Code[20]];

    /// <summary>Creates an owned signed and locked monthly prepaid contract due in January 2026, with owned contract invoice and credit memo series.</summary>
    procedure Create(var Header: Record "Service Contract Header")
    var
        Line: Record "Service Contract Line";
        Setup: Record "Service Mgt. Setup";
    begin
        if not Snapshotted then begin
            PriorSetup.Get();
            Snapshotted := true;
        end;
        BaseFixture.Create(Header, false);
        Header.Status := Header.Status::Signed;
        Header."Change Status" := Header."Change Status"::Locked;
        Header.Prepaid := true;
        Header."Next Invoice Date" := DMY2Date(1, 1, 2026);
        Header.Modify();
        Line.Get(Header."Contract Type", Header."Contract No.", 10000);
        Line."Invoiced to Date" := DMY2Date(31, 12, 2025);
        Line."New Line" := false;
        Line."Contract Status" := Line."Contract Status"::Signed;
        Line.Modify();
        Contracts.Add(Header."Contract No.");
        Setup.Get();
        Setup."Contract Serv. Ord.  Max. Days" := 366;
        Setup."Contract Invoice Nos." := Setup."Service Invoice Nos.";
        Setup."Contract Credit Memo Nos." := Setup."Service Credit Memo Nos.";
        Setup.Modify();
    end;

    /// <summary>Prepares an invoiced contract line for a partial-period credit without posting any document.</summary>
    procedure PrepareCredit(Header: Record "Service Contract Header")
    var
        Line: Record "Service Contract Line";
    begin
        Header.Prepaid := false;
        Header.Modify();
        Line.Get(Header."Contract Type", Header."Contract No.", 10000);
        Line."Invoiced to Date" := DMY2Date(31, 1, 2026);
        Line."Contract Expiration Date" := DMY2Date(15, 1, 2026);
        Line."Credit Memo Date" := DMY2Date(15, 1, 2026);
        Line.Modify();
    end;

    /// <summary>Builds a valid confirmed request for any periodic operation.</summary>
    procedure Request(TypeValue: Enum "Message Type ori"; Header: Record "Service Contract Header"): JsonObject
    var
        Result: JsonObject;
        Numbers: JsonArray;
    begin
        Result.Add('expectedCount', 1);
        if TypeValue = TypeValue::"Service.Contract.CreateCreditMemo" then begin
            Result.Add('contractNo', Header."Contract No.");
            Result.Add('creditMemoDateTo', '2026-01-31');
        end else begin
            Numbers.Add(Header."Contract No.");
            Result.Add('contractNos', Numbers);
            if TypeValue = TypeValue::"Service.Contract.CreateInvoices" then begin
                Result.Add('postingDate', '2026-01-31');
                Result.Add('invoiceToDate', '2026-01-31');
            end else begin
                Result.Add('startingDate', '2026-01-01');
                Result.Add('endingDate', '2026-01-31');
            end;
        end;
        exit(Result);
    end;

    /// <summary>Lists the three operations under test.</summary>
    procedure Types(): List of [Enum "Message Type ori"]
    var
        Values: List of [Enum "Message Type ori"];
    begin
        Values.Add("Message Type ori"::"Service.Contract.CreateInvoices");
        Values.Add("Message Type ori"::"Service.Contract.CreateServiceOrders");
        Values.Add("Message Type ori"::"Service.Contract.CreateCreditMemo");
        exit(Values);
    end;

    /// <summary>Deletes only owned item lines, delegates owned fixture cleanup and restores job setup.</summary>
    procedure Cleanup()
    var
        ItemLine: Record "Service Item Line";
        Setup: Record "Service Mgt. Setup";
        Number: Code[20];
    begin
        foreach Number in Contracts do begin
            ItemLine.SetRange("Contract No.", Number);
            ItemLine.DeleteAll(false);
        end;
        if Snapshotted then begin
            Setup.Get();
            Setup."Last Contract Service Date" := PriorSetup."Last Contract Service Date";
            Setup."Contract Serv. Ord.  Max. Days" := PriorSetup."Contract Serv. Ord.  Max. Days";
            Setup."Contract Invoice Nos." := PriorSetup."Contract Invoice Nos.";
            Setup."Contract Credit Memo Nos." := PriorSetup."Contract Credit Memo Nos.";
            Setup.Modify();
            Snapshotted := false;
        end;
        BaseFixture.Cleanup();
        Clear(Contracts);
    end;
}
