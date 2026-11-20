namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Origo.Bifrost;

/// <summary>Validates all selected shipments before adding their remaining quantities to an invoice.</summary>
codeunit 10076102 "Svc Inv Shipment Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Validation: Codeunit "Svc Doc Request ori";
        SelectionLbl: Label 'Send shipmentNos as 1 to 200 distinct shipment numbers, or allUninvoiced true, but not both.', Comment = 'is-IS=Sendu shipmentNos sem 1 til 200 mismunandi afhendingarnúmer eða allUninvoiced true, en ekki hvort tveggja.';
        CustomerLbl: Label 'Use shipments with the same customer, bill-to customer and currency as the invoice.', Comment = 'is-IS=Notaðu afhendingar með sama viðskiptamann, greiðanda og gjaldmiðil og reikningurinn.';
        MissingLbl: Label 'Read the posted service shipments and send an existing shipment number.', Comment = 'is-IS=Lestu bókaðar þjónustuafhendingar og sendu afhendingarnúmer sem er til.';
        IdentityLbl: Label 'Send invoiceNo, systemId or subject for an existing invoice, or customerNo to create one.', Comment = 'is-IS=Sendu invoiceNo, systemId eða subject fyrir reikning sem er til eða customerNo til að stofna reikning.';
        OpenLbl: Label 'Use an open service invoice.', Comment = 'is-IS=Notaðu opinn þjónustureikning.';
        InvoicedLbl: Label 'No uninvoiced quantity remains.', Comment = 'is-IS=Ekkert óreikningsfært magn er eftir.';
        CorrectionLbl: Label 'Correction line.', Comment = 'is-IS=Leiðréttingarlína.';
        ExistingLbl: Label 'Already present on this invoice.', Comment = 'is-IS=Þegar til staðar á þessum reikningi.';

    trigger OnRun()
    var
        Header: Record "Service Header";
        ShipHeader: Record "Service Shipment Header";
        ShipLine: Record "Service Shipment Line";
        Line: Record "Service Line";
        GetShipment: Codeunit "Service-Get Shipment";
        WriteCheck: Codeunit "Svc Write Check ori";
        Numbers: List of [Code[20]];
        Number: Code[20];
        Request: JsonObject;
        Result: JsonObject;
        Shipment: JsonObject;
        Shipments: JsonArray;
        Skipped: JsonArray;
        Created: Boolean;
        AllUninvoiced: Boolean;
        BeforeCount: Integer;
        Added: Integer;
        TotalAdded: Integer;
    begin
        Rec.AssertIsLicensed();
        Rec.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Invoice.GetShipmentLines');
        if not Validation.CheckKeys(Rec, 'invoiceNo,systemId,customerNo,shipmentNos,allUninvoiced') then
            exit;
        Request := Rec.GetRequestJson();
        if not ReadSelection(Rec, Request, Numbers, AllUninvoiced) then
            exit;
        Header.LockTable();
        ShipLine.LockTable();
        ShipHeader.ReadIsolation(IsolationLevel::UpdLock);
        Line.LockTable();
        if not FindInvoice(Rec, Request, Header, Created) then
            exit;
        if AllUninvoiced then begin
            ShipHeader.SetRange("Customer No.", Header."Customer No.");
            ShipHeader.SetRange("Bill-to Customer No.", Header."Bill-to Customer No.");
            ShipHeader.SetRange("Currency Code", Header."Currency Code");
            ShipHeader.SetLoadFields("No.");
            if ShipHeader.FindSet() then
                repeat
                    Numbers.Add(ShipHeader."No.");
                until ShipHeader.Next() = 0;
            ShipHeader.Reset();
        end;
        foreach Number in Numbers do begin
            if not ShipHeader.Get(Number) then begin
                Validation.Refuse(Rec, "Bifrost Error Code ori"::RecordNotFound, 'shipmentNos', MissingLbl);
                exit;
            end;
            if (ShipHeader."Customer No." <> Header."Customer No.") or
               (ShipHeader."Bill-to Customer No." <> Header."Bill-to Customer No.") or
               (ShipHeader."Currency Code" <> Header."Currency Code")
            then begin
                Validation.Refuse(Rec, "Bifrost Error Code ori"::ConflictingIdentifiers, 'shipmentNos', CustomerLbl);
                exit;
            end;
        end;
        // All structured refusals precede the first insert. Native validation errors roll back the processor.
        if Created then begin
            Number := Header."Customer No.";
            Clear(Header);
            Header.Init();
            Header."Document Type" := Header."Document Type"::Invoice;
            Header.Insert(true);
            Header.SetHideValidationDialog(true);
            Header.Validate("Customer No.", Number);
            Header.Modify(true);
        end;
        GetShipment.SetServiceHeader(Header);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        foreach Number in Numbers do begin
            Clear(Shipment);
            BeforeCount := Line.Count();
            ShipLine.Reset();
            ShipLine.ReadIsolation(IsolationLevel::UpdLock);
            ShipLine.ClearMarks();
            ShipLine.SetRange("Document No.", Number);
            if ShipLine.FindSet() then
                repeat
                    if ShipLine.Correction then
                        AddSkipped(Skipped, ShipLine, CorrectionLbl)
                    else
                        if ShipLine."Qty. Shipped Not Invoiced" = 0 then
                            AddSkipped(Skipped, ShipLine, InvoicedLbl)
                        else
                            if AlreadyAdded(Header, ShipLine) then
                                AddSkipped(Skipped, ShipLine, ExistingLbl)
                            else
                                ShipLine.Mark(true);
                until ShipLine.Next() = 0;
            ShipLine.MarkedOnly(true);
            GetShipment.CreateInvLines(ShipLine);
            Added := Line.Count() - BeforeCount;
            TotalAdded += Added;
            Shipment.Add('shipmentNo', Number);
            Shipment.Add('linesAdded', Added);
            Shipments.Add(Shipment);
        end;
        Result.Add('status', 'Success');
        Result.Add('invoiceNo', Header."No.");
        Result.Add('systemId', Format(Header.SystemId, 0, 4));
        Result.Add('created', Created);
        Result.Add('linesAdded', TotalAdded);
        Result.Add('shipments', Shipments);
        Result.Add('skipped', Skipped);
        Rec.SetResponseJson(Result);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure ReadSelection(var Argument: Record "Message Argument ori"; Request: JsonObject; var Numbers: List of [Code[20]]; var AllUninvoiced: Boolean): Boolean
    var
        Token: JsonToken;
        Element: JsonToken;
        Raw: Text;
        Number: Code[20];
        TextNumber: Text;
    begin
        if Request.Get('allUninvoiced', Token) then begin
            Token.WriteTo(Raw);
            if not (Raw in ['true', 'false']) then
                exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'allUninvoiced', SelectionLbl));
            AllUninvoiced := Raw = 'true';
        end;
        if Request.Get('shipmentNos', Token) then begin
            if AllUninvoiced or not Token.IsArray() then
                exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shipmentNos', SelectionLbl));
            if (Token.AsArray().Count() < 1) or (Token.AsArray().Count() > 200) then
                exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shipmentNos', SelectionLbl));
            foreach Element in Token.AsArray() do begin
                Element.WriteTo(Raw);
                if not Element.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then
                    exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shipmentNos', SelectionLbl));
                TextNumber := Element.AsValue().AsText().Trim();
                if (TextNumber = '') or (StrLen(TextNumber) > MaxStrLen(Number)) then
                    exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shipmentNos', SelectionLbl));
                Number := CopyStr(TextNumber, 1, MaxStrLen(Number));
                if Numbers.Contains(Number) then
                    exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shipmentNos', SelectionLbl));
                Numbers.Add(Number);
            end;
        end;
        if (Numbers.Count() = 0) and not AllUninvoiced then
            exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'shipmentNos', SelectionLbl));
        exit(true);
    end;

    local procedure FindInvoice(var Argument: Record "Message Argument ori"; Request: JsonObject; var Header: Record "Service Header"; var Created: Boolean): Boolean
    var
        Customer: Record Customer;
        TempLookupArgument: Record "Message Argument ori";
        Lookup: Codeunit "Svc Document Lookup ori";
        Identity: JsonObject;
        Token: JsonToken;
        InvoiceNo: Text;
        CustomerNo: Text;
    begin
        if not Validation.ReadText(Argument, Request, 'invoiceNo', 20, InvoiceNo) then
            exit(false);
        if not Validation.ReadText(Argument, Request, 'customerNo', 20, CustomerNo) then
            exit(false);
        Created := CustomerNo <> '';
        if Created then begin
            if (InvoiceNo <> '') or Request.Contains('systemId') or (Argument.Subject <> '') then
                exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'customerNo', IdentityLbl));
            if not Customer.Get(CustomerNo) then
                exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'customerNo', IdentityLbl));
            Header."Document Type" := Header."Document Type"::Invoice;
            Header."Customer No." := Customer."No.";
            Header."Bill-to Customer No." := Customer."Bill-to Customer No.";
            if Header."Bill-to Customer No." = '' then
                Header."Bill-to Customer No." := Customer."No.";
            Customer.Get(Header."Bill-to Customer No.");
            Header."Currency Code" := Customer."Currency Code";
            exit(true);
        end;
        TempLookupArgument := Argument;
        TempLookupArgument.Insert();
        if InvoiceNo <> '' then
            Identity.Add('no', InvoiceNo);
        if Request.Get('systemId', Token) then
            Identity.Add('systemId', Token);
        TempLookupArgument.SetRequestJson(Identity);
        if not Lookup.FindDocument(TempLookupArgument, Header."Document Type"::Invoice, Header) then begin
            Argument.SetResponseJson(TempLookupArgument.GetResponseJson());
            exit(false);
        end;
        if Header."Release Status" <> Header."Release Status"::Open then
            exit(Validation.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'invoiceNo', OpenLbl));
        exit(true);
    end;

    local procedure AlreadyAdded(Header: Record "Service Header"; ShipmentLine: Record "Service Shipment Line"): Boolean
    var
        Line: Record "Service Line";
    begin
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.SetRange("Shipment No.", ShipmentLine."Document No.");
        Line.SetRange("Shipment Line No.", ShipmentLine."Line No.");
        Line.ReadIsolation(IsolationLevel::ReadCommitted);
        exit(not Line.IsEmpty());
    end;

    local procedure AddSkipped(var Skipped: JsonArray; Line: Record "Service Shipment Line"; Reason: Text)
    var
        Entry: JsonObject;
    begin
        Entry.Add('shipmentNo', Line."Document No.");
        Entry.Add('lineNo', Line."Line No.");
        Entry.Add('reason', Reason);
        Skipped.Add(Entry);
    end;
}
