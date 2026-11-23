namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Contract;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Ledger;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>Builds raw owned service contracts and their posting setup without demo-data lookups.</summary>
codeunit 97763 "Svc Contract Data ori"
{
    var
        PreviousSetup: Record "Service Mgt. Setup";
        HaveSnapshot: Boolean;

    /// <summary>Creates an owned customer, resource and posting setup without CRONUS lookups.</summary>
    local procedure CreateMasterData(var CustomerNo: Code[20]; var ResourceNo: Code[20])
    var
        Customer: Record Customer;
        Resource: Record Resource;
        UOM: Record "Unit of Measure";
        ResourceUOM: Record "Resource Unit of Measure";
        Account: Record "G/L Account";
        Receivables: Record "G/L Account";
        CustomerGroup: Record "Customer Posting Group";
        BusGroup: Record "Gen. Business Posting Group";
        ProdGroup: Record "Gen. Product Posting Group";
        VATBus: Record "VAT Business Posting Group";
        VATProd: Record "VAT Product Posting Group";
        Posting: Record "General Posting Setup";
        VAT: Record "VAT Posting Setup";
        ServiceSetup: Record "Service Mgt. Setup";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        CodeValue: Code[10];
    begin
        if not HaveSnapshot then begin
            PreviousSetup.Get();
            HaveSnapshot := true;
        end;
        CodeValue := CopyStr('X24' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(CodeValue));
        Account.Init();
        Account."No." := 'XS' + CodeValue;
        Account.Name := 'X-owned service billing account';
        Account."Account Type" := Account."Account Type"::Posting;
        Account."Direct Posting" := true;
        Account."Gen. Prod. Posting Group" := CodeValue;
        Account."VAT Prod. Posting Group" := CodeValue;
        Account.Insert(true);
        Receivables := Account;
        Receivables."No." := 'XR' + CodeValue;
        Receivables.Insert(true);
        BusGroup.Code := CodeValue;
        BusGroup.Insert(true);
        ProdGroup.Code := CodeValue;
        ProdGroup.Insert(true);
        VATBus.Code := CodeValue;
        VATBus.Insert(true);
        VATProd.Code := CodeValue;
        VATProd.Insert(true);
        Posting."Gen. Bus. Posting Group" := CodeValue;
        Posting."Gen. Prod. Posting Group" := CodeValue;
        Posting."Sales Account" := Account."No.";
        Posting."Sales Credit Memo Account" := Account."No.";
        Posting."Sales Line Disc. Account" := Account."No.";
        Posting."Sales Inv. Disc. Account" := Account."No.";
        Posting."COGS Account" := Account."No.";
        Posting."COGS Account (Interim)" := Account."No.";
        Posting.Insert(true);
        VAT."VAT Bus. Posting Group" := CodeValue;
        VAT."VAT Prod. Posting Group" := CodeValue;
        VAT."VAT Calculation Type" := VAT."VAT Calculation Type"::"Normal VAT";
        VAT."VAT %" := 0;
        VAT."Sales VAT Account" := Account."No.";
        VAT."Purchase VAT Account" := Account."No.";
        VAT.Insert(true);
        CustomerGroup.Code := CodeValue;
        CustomerGroup."Receivables Account" := Receivables."No.";
        CustomerGroup."Service Charge Acc." := Account."No.";
        CustomerGroup."Invoice Rounding Account" := Account."No.";
        CustomerGroup.Insert(true);
        Customer.Init();
        Customer."No." := 'XS' + CodeValue;
        Customer.Name := 'X-owned contract test customer';
        Customer."Gen. Bus. Posting Group" := CodeValue;
        Customer."VAT Bus. Posting Group" := CodeValue;
        Customer."Customer Posting Group" := CodeValue;
        Customer.Insert(true);
        CustomerNo := Customer."No.";
        UOM.Code := CodeValue;
        UOM.Description := 'X-owned unit';
        UOM.Insert(true);
        Resource.Init();
        Resource."No." := 'XS' + CodeValue;
        Resource.Name := 'X-owned billing resource';
        Resource.Type := Resource.Type::Person;
        Resource."Gen. Prod. Posting Group" := CodeValue;
        Resource."VAT Prod. Posting Group" := CodeValue;
        Resource."Unit Price" := 10;
        Resource.Insert(true);
        ResourceUOM."Resource No." := Resource."No.";
        ResourceUOM.Code := CodeValue;
        ResourceUOM."Qty. per Unit of Measure" := 1;
        ResourceUOM.Insert(true);
        Resource.Validate("Base Unit of Measure", CodeValue);
        Resource.Modify(true);
        ResourceNo := Resource."No.";
        Series.Code := CodeValue;
        Series."Default Nos." := true;
        Series."Manual Nos." := true;
        Series.Insert(true);
        SeriesLine."Series Code" := CodeValue;
        SeriesLine."Line No." := 10000;
        SeriesLine."Starting No." := CodeValue + '000001';
        SeriesLine."Ending No." := CodeValue + '999999';
        SeriesLine."Increment-by No." := 1;
        SeriesLine.Insert(true);
        if not ServiceSetup.Get() then begin
            ServiceSetup.Init();
            ServiceSetup.Insert(true);
        end;
        ServiceSetup."Service Order Nos." := CodeValue;
        ServiceSetup."Service Invoice Nos." := CodeValue;
        ServiceSetup."Service Credit Memo Nos." := CodeValue;
        ServiceSetup."Posted Service Shipment Nos." := CodeValue;
        ServiceSetup."Posted Service Invoice Nos." := CodeValue;
        ServiceSetup."Posted Serv. Credit Memo Nos." := CodeValue;
        ServiceSetup."Service Item Nos." := CodeValue;
        ServiceSetup."Service Zones Option" := ServiceSetup."Service Zones Option"::"Not Used";
        ServiceSetup."Resource Skills Option" := ServiceSetup."Resource Skills Option"::"Not Used";
        ServiceSetup.Modify(true);
    end;


    /// <summary>Creates one quote or unsigned contract with an owned customer and service item.</summary>
    procedure Create(var Header: Record "Service Contract Header"; Quote: Boolean)
    var
        Customer: Record Customer;
        Item: Record "Service Item";
        ItemGroup: Record "Service Item Group";
        Line: Record "Service Contract Line";
        AccountGroup: Record "Service Contract Account Group";
        Setup: Record "Service Mgt. Setup";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
    begin
        CreateMasterData(CustomerNo, ResourceNo);
        Customer.Get(CustomerNo);
        ItemGroup.Code := CopyStr(Customer."Gen. Bus. Posting Group", 1, MaxStrLen(ItemGroup.Code));
        ItemGroup.Insert();
        Item."No." := CustomerNo;
        Item."Customer No." := CustomerNo;
        Item."Service Item Group Code" := ItemGroup.Code;
        Item.Description := 'X-owned contract service item';
        Item.Insert();
        AccountGroup.Code := ItemGroup.Code;
        AccountGroup."Non-Prepaid Contract Acc." := CustomerNo;
        AccountGroup."Prepaid Contract Acc." := CustomerNo;
        AccountGroup.Insert();
        Header.Init();
        if Quote then
            Header."Contract Type" := Header."Contract Type"::Quote
        else
            Header."Contract Type" := Header."Contract Type"::Contract;
        Header."Contract No." := CustomerNo;
        Header."Customer No." := CustomerNo;
        Header."Bill-to Customer No." := CustomerNo;
        Header.Name := Customer.Name;
        Header."Bill-to Name" := Customer.Name;
        Header.Description := 'X-owned contract lifecycle fixture';
        Header."Starting Date" := DMY2Date(1, 1, 2026);
        Header."First Service Date" := Header."Starting Date";
        Header."Next Invoice Date" := DMY2Date(31, 1, 2026);
        Header."Next Invoice Period Start" := DMY2Date(1, 1, 2026);
        Header."Next Invoice Period End" := DMY2Date(31, 1, 2026);
        Header."Invoice Period" := Header."Invoice Period"::Month;
        Header."Annual Amount" := 1200;
        Header."Amount per Period" := 100;
        Header."Serv. Contract Acc. Gr. Code" := AccountGroup.Code;
        Evaluate(Header."Service Period", '<1M>');
        Header.Insert();
        Line."Contract Type" := Header."Contract Type";
        Line."Contract No." := Header."Contract No.";
        Line."Line No." := 10000;
        Line."Service Item No." := Item."No.";
        Line."Service Item Group Code" := ItemGroup.Code;
        Line."Customer No." := CustomerNo;
        Line.Description := Item.Description;
        Line."Starting Date" := Header."Starting Date";
        Line."Next Planned Service Date" := Header."Starting Date";
        Line."Response Time (Hours)" := 24;
        Line."Service Period" := Header."Service Period";
        Line."Line Value" := 1200;
        Line."Line Amount" := 1200;
        Line.Insert();
        Setup.Get();
        Setup."Salesperson Mandatory" := false;
        Setup.Modify();
    end;

    /// <summary>Restores setup; the codeunit-isolated test runner rolls back all owned fixture records.</summary>
    procedure RestoreSetup()
    var
        Setup: Record "Service Mgt. Setup";
    begin
        if HaveSnapshot then begin
            Setup.Get();
            Setup."Service Order Nos." := PreviousSetup."Service Order Nos.";
            Setup."Service Invoice Nos." := PreviousSetup."Service Invoice Nos.";
            Setup."Service Credit Memo Nos." := PreviousSetup."Service Credit Memo Nos.";
            Setup."Posted Service Shipment Nos." := PreviousSetup."Posted Service Shipment Nos.";
            Setup."Posted Service Invoice Nos." := PreviousSetup."Posted Service Invoice Nos.";
            Setup."Posted Serv. Credit Memo Nos." := PreviousSetup."Posted Serv. Credit Memo Nos.";
            Setup."Service Item Nos." := PreviousSetup."Service Item Nos.";
            Setup."Service Zones Option" := PreviousSetup."Service Zones Option";
            Setup."Resource Skills Option" := PreviousSetup."Resource Skills Option";
            Setup."Salesperson Mandatory" := PreviousSetup."Salesperson Mandatory";
            Setup.Modify();
            HaveSnapshot := false;
        end;
    end;

    /// <summary>Builds the documented request for a selected contract.</summary>
    procedure Request(Header: Record "Service Contract Header"; Confirm: Boolean): JsonObject
    var
        Result: JsonObject;
    begin
        if Header."Contract Type" = Header."Contract Type"::Quote then
            Result.Add('contractQuoteNo', Header."Contract No.")
        else
            Result.Add('contractNo', Header."Contract No.");
        if Confirm then begin
            Result.Add('expectedCount', 1);
            Result.Add('createInvoice', false);
        end;
        exit(Result);
    end;

    /// <summary>Restores setup and removes only this story's owned fixture records.</summary>
    procedure Cleanup()
    var
        Customer: Record Customer;
        Header: Record "Service Header";
        Entry: Record "Service Ledger Entry";
        Register: Record "Service Register";
        Setup: Record "Service Mgt. Setup";
        CustomerNo: Code[20];
        GroupCode: Code[20];
        FirstEntry: Integer;
        LastEntry: Integer;
    begin
        RestoreSetup();
        Customer.SetFilter(Name, '%1|%2', 'Owned billing test customer', 'X-owned contract test customer');
        Customer.SetFilter("No.", 'XSX24*');
        while Customer.FindFirst() do begin
            CustomerNo := Customer."No.";
            GroupCode := Customer."Gen. Bus. Posting Group";
            Header.SetRange("Customer No.", CustomerNo);
            while Header.FindFirst() do begin
                DeleteRows(Database::"Service Line", 'Document No.', Header."No.");
                Header.Delete(false);
            end;
            Entry.SetRange("Customer No.", CustomerNo);
            Entry.SetLoadFields("Entry No.");
            if Entry.FindFirst() then begin
                FirstEntry := Entry."Entry No.";
                Entry.FindLast();
                LastEntry := Entry."Entry No.";
                Register.SetRange("From Entry No.", FirstEntry);
                Register.SetRange("To Entry No.", LastEntry);
                Register.DeleteAll(false);
            end;
            DeleteRows(Database::"Service Ledger Entry", 'Customer No.', CustomerNo);
            DeleteRows(Database::"Filed Contract Line", 'Contract No.', CustomerNo);
            DeleteRows(Database::"Filed Service Contract Header", 'Contract No.', CustomerNo);
            DeleteRows(Database::"Contract Gain/Loss Entry", 'Contract No.', CustomerNo);
            DeleteRows(Database::"Contract Change Log", 'Contract No.', CustomerNo);
            DeleteRows(Database::"Service Contract Line", 'Contract No.', CustomerNo);
            DeleteRows(Database::"Service Contract Header", 'Contract No.', CustomerNo);
            DeleteRows(Database::"Service Contract Account Group", 'Code', GroupCode);
            DeleteRows(Database::"Service Item", 'No.', CustomerNo);
            DeleteRows(Database::"Service Item Group", 'Code', GroupCode);
            DeleteRows(Database::"Resource Unit of Measure", 'Resource No.', CustomerNo);
            DeleteRows(Database::Resource, 'No.', CustomerNo);
            DeleteRows(Database::"Unit of Measure", 'Code', GroupCode);
            DeleteRows(Database::"General Posting Setup", 'Gen. Bus. Posting Group', GroupCode);
            DeleteRows(Database::"VAT Posting Setup", 'VAT Bus. Posting Group', GroupCode);
            DeleteRows(Database::"Gen. Business Posting Group", 'Code', GroupCode);
            DeleteRows(Database::"Gen. Product Posting Group", 'Code', GroupCode);
            DeleteRows(Database::"VAT Business Posting Group", 'Code', GroupCode);
            DeleteRows(Database::"VAT Product Posting Group", 'Code', GroupCode);
            DeleteRows(Database::"Customer Posting Group", 'Code', GroupCode);
            DeleteRows(Database::"G/L Account", 'No.', 'XS' + GroupCode);
            DeleteRows(Database::"G/L Account", 'No.', 'XR' + GroupCode);
            Setup.Get();
            if not (GroupCode in [Setup."Service Order Nos.", Setup."Service Invoice Nos.", Setup."Service Credit Memo Nos.",
                Setup."Posted Service Shipment Nos.", Setup."Posted Service Invoice Nos.", Setup."Posted Serv. Credit Memo Nos.", Setup."Service Item Nos."])
            then begin
                DeleteRows(Database::"No. Series Line", 'Series Code', GroupCode);
                DeleteRows(Database::"No. Series", 'Code', GroupCode);
            end;
            Customer.Delete(false);
        end;
    end;

    local procedure DeleteRows(TableNo: Integer; FieldName: Text; Value: Text)
    var
        TableRef: RecordRef;
        FieldReference: FieldRef;
        Index: Integer;
        Found: Boolean;
    begin
        if Value = '' then
            Error('Fixture cleanup requires an exact nonempty value.');
        TableRef.Open(TableNo);
        for Index := 1 to TableRef.FieldCount() do begin
            FieldReference := TableRef.FieldIndex(Index);
            if FieldReference.Name() = FieldName then begin
                FieldReference.SetRange(Value);
                Found := true;
                break;
            end;
        end;
        if not Found then
            Error('Fixture cleanup field %1 is missing on table %2.', FieldName, TableNo);
        TableRef.DeleteAll(false);
        TableRef.Close();
    end;
}
