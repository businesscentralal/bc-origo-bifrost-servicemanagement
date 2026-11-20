namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.VAT.Ledger;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Sales.Receivables;
using Microsoft.Service.History;
using Microsoft.Service.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>Builds standalone billing fixtures from raw owned master data and posting setup.</summary>
codeunit 97760 "Svc Doc Fixture ori"
{
    var
        PreviousSetup: Record "Service Mgt. Setup";
        HaveSnapshot: Boolean;

    /// <summary>Creates an owned customer, resource and posting setup without CRONUS lookups.</summary>
    procedure Create(var CustomerNo: Code[20]; var ResourceNo: Code[20])
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
        CodeValue := CopyStr('SD22' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(CodeValue));
        Account.Init();
        Account."No." := 'SD' + CodeValue;
        Account.Name := 'Owned service billing account';
        Account."Account Type" := Account."Account Type"::Posting;
        Account."Direct Posting" := true;
        Account.Insert(true);
        Receivables := Account;
        Receivables."No." := 'SR' + CodeValue;
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
        Customer."No." := 'SD' + CodeValue;
        Customer.Name := 'Owned billing test customer';
        Customer."Gen. Bus. Posting Group" := CodeValue;
        Customer."VAT Bus. Posting Group" := CodeValue;
        Customer."Customer Posting Group" := CodeValue;
        Customer.Insert(true);
        CustomerNo := Customer."No.";
        UOM.Code := CodeValue;
        UOM.Description := 'Owned unit';
        UOM.Insert(true);
        Resource.Init();
        Resource."No." := 'SD' + CodeValue;
        Resource.Name := 'Owned billing resource';
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

    /// <summary>Creates an owned document with one resource line and an order service item when required.</summary>
    procedure Document(var Header: Record "Service Header"; DocumentType: Enum "Service Document Type"; CustomerNo: Code[20]; ResourceNo: Code[20])
    var
        Line: Record "Service Line";
        Item: Record "Service Item";
        ItemLine: Record "Service Item Line";
    begin
        Header.Init();
        Header."Document Type" := DocumentType;
        Header.Insert(true);
        Header.SetHideValidationDialog(true);
        Header.Validate("Customer No.", CustomerNo);
        Header.Validate("Posting Date", WorkDate());
        Header.Modify(true);
        if DocumentType = DocumentType::Order then begin
            Item.Init();
            Item.Insert(true);
            Item.Validate("Customer No.", CustomerNo);
            Item.Modify(true);
            ItemLine.Init();
            ItemLine."Document Type" := DocumentType;
            ItemLine."Document No." := Header."No.";
            ItemLine."Line No." := 10000;
            ItemLine.Insert(true);
            ItemLine.Validate("Service Item No.", Item."No.");
            ItemLine.Modify(true);
        end;
        Line.Init();
        Line."Document Type" := DocumentType;
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line.Insert(true);
        Line.Validate(Type, Line.Type::Resource);
        Line.Validate("No.", ResourceNo);
        if DocumentType = DocumentType::Order then
            Line.Validate("Service Item Line No.", ItemLine."Line No.");
        Line.Validate(Quantity, 2);
        Line.Validate("Unit Price", 10);
        Line.Modify(true);
    end;

    /// <summary>Builds a posting or preview request for the document.</summary>
    procedure Request(Header: Record "Service Header"; Count: Integer) Result: JsonObject
    begin
        if Header."Document Type" = Header."Document Type"::Invoice then
            Result.Add('documentType', 'Invoice')
        else
            Result.Add('documentType', 'CreditMemo');
        Result.Add('no', Header."No.");
        if Count > 0 then
            Result.Add('expectedCount', Count);
    end;
    /// <summary>Restores service setup and removes only this fixture's explicitly named data.</summary>
    procedure Cleanup()
    var
        Customer: Record Customer;
        GLEntry: Record "G/L Entry";
        GLVATLink: Record "G/L Entry - VAT Entry Link";
        ServiceSetup: Record "Service Mgt. Setup";
        CustomerNo: Code[20];
        GroupCode: Code[20];
    begin
        if HaveSnapshot then begin
            ServiceSetup.Get();
            ServiceSetup.TransferFields(PreviousSetup, false);
            ServiceSetup.Modify(false);
            HaveSnapshot := false;
        end;
        Customer.SetRange(Name, 'Owned billing test customer');
        Customer.SetFilter("No.", 'SD*');
        while Customer.FindFirst() do begin
            CustomerNo := Customer."No.";
            GroupCode := Customer."Gen. Bus. Posting Group";
            DeleteDocuments(Database::"Service Header", Database::"Service Line", CustomerNo);
            DeleteDocuments(Database::"Service Shipment Header", Database::"Service Shipment Line", CustomerNo);
            DeleteDocuments(Database::"Service Invoice Header", Database::"Service Invoice Line", CustomerNo);
            DeleteDocuments(Database::"Service Cr.Memo Header", Database::"Service Cr.Memo Line", CustomerNo);
            DeleteRows(Database::"Service Item", 'Customer No.', CustomerNo);
            GLEntry.SetRange("Source No.", CustomerNo);
            GLEntry.SetLoadFields("Entry No.");
            if GLEntry.FindSet() then
                repeat
                    GLVATLink.SetRange("G/L Entry No.", GLEntry."Entry No.");
                    GLVATLink.DeleteAll(false);
                until GLEntry.Next() = 0;
            DeleteRows(Database::"G/L Entry", 'Source No.', CustomerNo);
            DeleteRows(Database::"VAT Entry", 'Bill-to/Pay-to No.', CustomerNo);
            DeleteRows(Database::"Detailed Cust. Ledg. Entry", 'Customer No.', CustomerNo);
            DeleteRows(Database::"Cust. Ledger Entry", 'Customer No.', CustomerNo);
            DeleteRows(Database::"Service Ledger Entry", 'Customer No.', CustomerNo);
            DeleteRows(Database::"Res. Ledger Entry", 'Resource No.', CustomerNo);
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
            DeleteRows(Database::"G/L Account", 'No.', 'SD' + GroupCode);
            DeleteRows(Database::"G/L Account", 'No.', 'SR' + GroupCode);
            // Keep a pre-existing series if the restored tenant setup still references it.
            ServiceSetup.Get();
            if not (GroupCode in [ServiceSetup."Service Order Nos.", ServiceSetup."Service Invoice Nos.",
                ServiceSetup."Service Credit Memo Nos.", ServiceSetup."Service Item Nos.",
                ServiceSetup."Posted Service Shipment Nos.", ServiceSetup."Posted Service Invoice Nos.",
                ServiceSetup."Posted Serv. Credit Memo Nos."])
            then begin
                DeleteRows(Database::"No. Series Line", 'Series Code', GroupCode);
                DeleteRows(Database::"No. Series", 'Code', GroupCode);
            end;
            Customer.Delete(false);
        end;
    end;

    local procedure DeleteDocuments(HeaderTable: Integer; LineTable: Integer; CustomerNo: Code[20])
    var
        HeaderRef: RecordRef;
        NumberField: FieldRef;
        CustomerField: FieldRef;
        Number: Text;
    begin
        HeaderRef.Open(HeaderTable);
        CustomerField := NamedField(HeaderRef, 'Customer No.');
        CustomerField.SetRange(CustomerNo);
        while HeaderRef.FindFirst() do begin
            NumberField := NamedField(HeaderRef, 'No.');
            Number := Format(NumberField.Value());
            DeleteRows(LineTable, 'Document No.', Number);
            case HeaderTable of
                Database::"Service Header": DeleteRows(Database::"Service Item Line", 'Document No.', Number);
                Database::"Service Shipment Header": DeleteRows(Database::"Service Shipment Item Line", 'No.', Number);
            end;
            HeaderRef.Delete(false);
        end;
        HeaderRef.Close();
    end;

    local procedure DeleteRows(TableNo: Integer; FieldName: Text; Value: Text)
    var
        TableRef: RecordRef;
        FieldReference: FieldRef;
    begin
        if Value = '' then
            Error('Fixture cleanup requires an exact nonempty value.');
        TableRef.Open(TableNo);
        FieldReference := NamedField(TableRef, FieldName);
        FieldReference.SetRange(Value);
        TableRef.DeleteAll(false);
        TableRef.Close();
    end;

    local procedure NamedField(var TableRef: RecordRef; FieldName: Text): FieldRef
    var
        FieldReference: FieldRef;
        Index: Integer;
    begin
        for Index := 1 to TableRef.FieldCount() do begin
            FieldReference := TableRef.FieldIndex(Index);
            if FieldReference.Name() = FieldName then
                exit(FieldReference);
        end;
        Error('Fixture cleanup field %1 is missing on table %2.', FieldName, TableRef.Number());
    end;

}
