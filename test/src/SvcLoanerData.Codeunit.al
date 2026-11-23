namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Item;
using Microsoft.Service.Loaner;
using Origo.Bifrost;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Creates owned loaner fixtures from raw records, without company defaults or demo data.</summary>
codeunit 97765 "Svc Loaner Data ori"
{
    var
        ExpectedLoanerNo: Code[20];

    /// <summary>Creates a customer with a posting group, service item, order line and available loaner.</summary>
    procedure Create(var Line: Record "Service Item Line"; var Loaner: Record Loaner)
    var
        Customer: Record Customer;
        CustomerGroup: Record "Customer Posting Group";
        Item: Record "Service Item";
        ItemGroup: Record "Service Item Group";
        Header: Record "Service Header";
        Number: Code[20];
    begin
        Number := CopyStr('X26' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20);
        CustomerGroup.Code := Number;
        CustomerGroup.Insert();
        Customer."No." := Number;
        Customer.Name := 'Owned loaner test customer';
        Customer."Customer Posting Group" := Number;
        Customer.Insert();
        ItemGroup.Code := CopyStr(Number, 1, MaxStrLen(ItemGroup.Code));
        ItemGroup.Insert();
        Item."No." := Number;
        Item."Customer No." := Number;
        Item."Service Item Group Code" := ItemGroup.Code;
        Item.Insert();
        Header."Document Type" := Header."Document Type"::Order;
        Header."No." := Number;
        Header."Customer No." := Number;
        Header."Order Date" := WorkDate();
        Header.Insert();
        Line.Init();
        Line."Document Type" := Header."Document Type";
        Line."Document No." := Number;
        Line."Line No." := 10000;
        Line."Service Item No." := Item."No.";
        Line."Service Item Group Code" := ItemGroup.Code;
        Line.Insert();
        Loaner.Init();
        Loaner."No." := Number;
        Loaner.Description := 'Owned loaner test';
        Loaner.Insert();
        ExpectedLoanerNo := Loaner."No.";
    end;

    /// <summary>Uses the public generic field-write operation to lend, preserving BC field validation.</summary>
    procedure GenericLend(Line: Record "Service Item Line"; LoanerNo: Code[20]; LanguageId: Integer): JsonObject
    var
        ChangeLog: Record "Change Log Setup";
        ChangeLogTable: Record "Change Log Setup (Table)";
        PriorLog: Record "Change Log Setup";
        PriorTable: Record "Change Log Setup (Table)";
        Data: Codeunit "Svc Test Data ori";
        Payload: JsonObject;
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
        Response: JsonObject;
        HadLog: Boolean;
        HadTable: Boolean;
    begin
        HadLog := PriorLog.Get();
        HadTable := PriorTable.Get(Database::"Service Item Line");
        if not ChangeLog.Get() then
            ChangeLog.Insert();
        ChangeLog."Change Log Activated" := true;
        ChangeLog.Modify();
        if not ChangeLogTable.Get(Database::"Service Item Line") then begin
            ChangeLogTable."Table No." := Database::"Service Item Line";
            ChangeLogTable.Insert();
        end;
        ChangeLogTable."Log Modification" := ChangeLogTable."Log Modification"::"All Fields";
        ChangeLogTable.Modify();
        Commit();
        Fields.Add('LoanerNo_', LoanerNo);
        Entry.Add('id', Format(Line.SystemId, 0, 4));
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Payload.Add('tableName', 'Service Item Line');
        Payload.Add('data', Entries);
        Response := Data.Invoke("Message Type ori"::"Data.Records.Set", Payload, '', LanguageId, false);
        if HadLog then begin
            ChangeLog := PriorLog;
            ChangeLog.Modify();
        end else
            ChangeLog.Delete();
        if HadTable then begin
            ChangeLogTable := PriorTable;
            ChangeLogTable.Modify();
        end else
            ChangeLogTable.Delete();
        Commit();
        exit(Response);
    end;

    /// <summary>Lends through the dedicated public operation.</summary>
    procedure Lend(Line: Record "Service Item Line"; LoanerNo: Code[20]; LanguageId: Integer): JsonObject
    var
        Data: Codeunit "Svc Test Data ori";
        Payload: JsonObject;
    begin
        ExpectedLoanerNo := LoanerNo;
        Payload := Request(Line);
        Payload.Add('loanerNo', LoanerNo);
        exit(Data.Invoke("Message Type ori"::"Service.Loaner.Lend", Payload, '', LanguageId, false));
    end;

    /// <summary>Checks a native confirmation concerns the exact loaner selected by the test, independently of translated nouns.</summary>
    procedure AssertConfirmation(Question: Text)
    var
        Assert: Codeunit "Library Assert";
    begin
        Assert.AreNotEqual('', ExpectedLoanerNo, 'A test must select its loaner before confirming.');
        Assert.IsTrue(Question.Contains(ExpectedLoanerNo), 'Confirmation must name the selected owned loaner: ' + Question);
    end;

    /// <summary>Builds the open-order identifier set.</summary>
    procedure Request(Line: Record "Service Item Line"): JsonObject
    var
        Value: JsonObject;
    begin
        Value.Add('documentNo', Line."Document No.");
        Value.Add('serviceItemLineNo', Line."Line No.");
        exit(Value);
    end;

    /// <summary>Creates owned posted shipment records referencing the same service order loan.</summary>
    procedure Shipment(Line: Record "Service Item Line"; var ShipmentLine: Record "Service Shipment Item Line")
    var
        Header: Record "Service Shipment Header";
    begin
        Header."No." := Line."Document No.";
        Header."Order No." := Line."Document No.";
        Header.Insert();
        ShipmentLine."No." := Header."No.";
        ShipmentLine."Line No." := Line."Line No.";
        ShipmentLine."Service Item No." := Line."Service Item No.";
        ShipmentLine."Loaner No." := Line."Loaner No.";
        ShipmentLine.Insert();
    end;
    /// <summary>Removes only this story's marked fixtures and their native loan history after verification.</summary>
    procedure Cleanup()
    var
        Loaner: Record Loaner;
        Entry: Record "Loaner Entry";
        Header: Record "Service Header";
        Line: Record "Service Item Line";
        ShipmentHeader: Record "Service Shipment Header";
        ShipmentLine: Record "Service Shipment Item Line";
        DocumentLog: Record "Service Document Log";
        Customer: Record Customer;
        CustomerGroup: Record "Customer Posting Group";
        Item: Record "Service Item";
        ItemGroup: Record "Service Item Group";
    begin
        Loaner.SetFilter("No.", 'X26*');
        Loaner.SetFilter(Description, 'Owned loaner test|XSM26-*');
        Loaner.SetLoadFields("No.");
        if Loaner.FindSet() then
            repeat
                Entry.SetRange("Loaner No.", Loaner."No.");
                Entry.DeleteAll();
                Line.SetRange("Document Type", Line."Document Type"::Order);
                Line.SetRange("Document No.", Loaner."No.");
                Line.DeleteAll();
                Header.SetRange("Document Type", Header."Document Type"::Order);
                Header.SetRange("No.", Loaner."No.");
                Header.DeleteAll();
                ShipmentLine.SetRange("No.", Loaner."No.");
                ShipmentLine.DeleteAll();
                ShipmentHeader.SetRange("No.", Loaner."No.");
                ShipmentHeader.DeleteAll();
                DocumentLog.SetRange("Document Type", DocumentLog."Document Type"::Order);
                DocumentLog.SetRange("Document No.", Loaner."No.");
                DocumentLog.DeleteAll();
                if Item.Get(Loaner."No.") then begin
                    if ItemGroup.Get(Item."Service Item Group Code") then
                        ItemGroup.Delete();
                    Item.Delete();
                end;
                if Customer.Get(Loaner."No.") then
                    Customer.Delete();
                if CustomerGroup.Get(Loaner."No.") then
                    CustomerGroup.Delete();
                Loaner.Delete();
            until Loaner.Next() = 0;
    end;
}
