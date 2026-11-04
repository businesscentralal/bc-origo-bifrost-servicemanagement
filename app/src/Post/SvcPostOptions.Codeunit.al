namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Ledger;
using Origo.Bifrost;
using System.Security.User;

/// <summary>Reads and checks the ship, consume and invoice options, and collects the documents a posting created.</summary>
codeunit 10076083 "Svc Post Options ori"
{
    Access = Internal;

    var
        BadFlags: List of [Text];
        CorrectLbl: Label 'Send true or false, or leave the key out.', Comment = 'is-IS=Sendu true eða false, eða slepptu lyklinum.';
        BooleanLbl: Label '%1 must be a JSON boolean.', Comment = '%1 = parameter, is-IS=%1 verður að vera JSON boolean.';

    /// <summary>Reads ship, consume and invoice; a value that is not a JSON boolean is collected as InvalidParameterFormat.</summary>
    /// <param name="Argument">Receives collected format errors.</param>
    /// <param name="Ship">The requested ship flag, false when not sent.</param>
    /// <param name="Consume">The requested consume flag, false when not sent.</param>
    /// <param name="Invoice">The requested invoice flag, false when not sent.</param>
    /// <param name="AnySent">True when at least one of the three keys was sent.</param>
    internal procedure ReadFlags(var Argument: Record "Message Argument ori"; var Ship: Boolean; var Consume: Boolean; var Invoice: Boolean; var AnySent: Boolean)
    var
        Request: JsonObject;
        Sent: Boolean;
    begin
        Request := Argument.GetRequestJson();
        Ship := ReadFlag(Request, 'ship', Sent);
        AnySent := Sent;
        Consume := ReadFlag(Request, 'consume', Sent);
        AnySent := AnySent or Sent;
        Invoice := ReadFlag(Request, 'invoice', Sent);
        AnySent := AnySent or Sent;
    end;

    /// <summary>Answers flags that are not JSON booleans: one problem as InvalidParameterFormat, several as MultipleErrors.</summary>
    /// <param name="Argument">Receives the answer.</param>
    /// <returns>True when an answer was given and the call must stop.</returns>
    internal procedure RespondBadFlags(var Argument: Record "Message Argument ori"): Boolean
    var
        NothingPostedLbl: Label 'Nothing was posted.', Comment = 'is-IS=Ekkert var bókað.';
        Entry: Text;
        Parts: List of [Text];
    begin
        if BadFlags.Count() = 0 then
            exit(false);
        if BadFlags.Count() = 1 then begin
            Parts := BadFlags.Get(1).Split('|');
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(BooleanLbl, Parts.Get(1)), Parts.Get(1), Parts.Get(2), 'boolean', CorrectLbl);
            exit(true);
        end;
        foreach Entry in BadFlags do begin
            Parts := Entry.Split('|');
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(BooleanLbl, Parts.Get(1)), Parts.Get(1), Parts.Get(2), 'boolean', CorrectLbl);
        end;
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, NothingPostedLbl);
        exit(true);
    end;

    /// <summary>Applies the default and refuses combinations Business Central does not offer or the user policy forbids.</summary>
    /// <param name="Argument">Receives the refusal.</param>
    /// <param name="Ship">The ship flag, defaulted when no flag was sent.</param>
    /// <param name="Consume">The consume flag.</param>
    /// <param name="Invoice">The invoice flag, defaulted when no flag was sent.</param>
    /// <param name="AnySent">True when the caller sent at least one flag.</param>
    /// <returns>True when the combination may be posted.</returns>
    internal procedure Resolve(var Argument: Record "Message Argument ori"; var Ship: Boolean; Consume: Boolean; var Invoice: Boolean; AnySent: Boolean): Boolean
    var
        ConsumeInvoiceErr: Label 'consume and invoice cannot be posted together. Send ship and consume, or invoice.', Comment = 'is-IS=Ekki er hægt að bóka consume og invoice saman. Sendu ship og consume, eða invoice.';
        ConsumeInvoiceNextLbl: Label 'Send ship and consume, or invoice.', Comment = 'is-IS=Sendu ship og consume, eða invoice.';
        ConsumeShipErr: Label 'consume needs ship = true.', Comment = 'is-IS=consume krefst ship = true.';
        ConsumeShipNextLbl: Label 'Send ship = true together with consume.', Comment = 'is-IS=Sendu ship = true ásamt consume.';
        NoneErr: Label 'ship, consume and invoice are all false: nothing would be posted.', Comment = 'is-IS=ship, consume og invoice eru öll false: ekkert yrði bókað.';
        NoneNextLbl: Label 'Set ship, invoice or ship and consume to true, or leave all three out.', Comment = 'is-IS=Settu ship, invoice eða ship og consume á true, eða slepptu þeim öllum.';
        TrueExpectedLbl: Label 'true', Locked = true;
    begin
        if not AnySent then begin
            Ship := true;
            Invoice := true;
        end;
        if Consume and Invoice then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, ConsumeInvoiceErr, 'consume', 'true', TrueExpectedLbl, ConsumeInvoiceNextLbl);
            exit(false);
        end;
        if Consume and not Ship then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, ConsumeShipErr, 'ship', 'false', TrueExpectedLbl, ConsumeShipNextLbl);
            exit(false);
        end;
        if not (Ship or Consume or Invoice) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, NoneErr, 'ship', 'false', TrueExpectedLbl, NoneNextLbl);
            exit(false);
        end;
        exit(CheckPolicy(Argument, Ship, Consume, Invoice));
    end;

    /// <summary>Refuses a combination the user's service invoice posting policy does not allow.</summary>
    /// <param name="Argument">Receives the refusal.</param>
    /// <param name="Ship">The requested ship flag.</param>
    /// <param name="Consume">The requested consume flag.</param>
    /// <param name="Invoice">The requested invoice flag.</param>
    /// <returns>True when the policy allows the combination.</returns>
    internal procedure CheckPolicy(var Argument: Record "Message Argument ori"; Ship: Boolean; Consume: Boolean; Invoice: Boolean): Boolean
    var
        UserSetup: Record "User Setup";
        Policy: Enum "Invoice Posting Policy";
        Violation: Boolean;
        PolicyErr: Label 'Your service invoice posting policy does not allow this combination. Nothing was posted.', Comment = 'is-IS=Bókunarregla þjónustureikninga þinna leyfir ekki þessa samsetningu. Ekkert var bókað.';
        PolicyNextLbl: Label 'Ask an administrator to check the policy in User Setup.', Comment = 'is-IS=Biddu stjórnanda um að skoða regluna í notandauppsetningu.';
    begin
        // Mirrors Serv. Posting Selection Mgt.: Prohibited forbids invoicing, Mandatory forbids shipping or consuming without invoicing.
        if UserSetup.Get(UserId()) then
            Policy := UserSetup."Service Invoice Posting Policy";
        case Policy of
            Policy::Prohibited:
                Violation := Invoice;
            Policy::Mandatory:
                Violation := (Ship or Consume) and not Invoice;
        end;
        if not Violation then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, PolicyErr, 'invoice', Format(Invoice), '', PolicyNextLbl);
        exit(false);
    end;

    /// <summary>Refuses an order whose lines hold no quantity for the requested options.</summary>
    /// <param name="Argument">Receives the PreconditionFailed answer.</param>
    /// <param name="Header">The service order.</param>
    /// <param name="Ship">The ship flag.</param>
    /// <param name="Consume">The consume flag.</param>
    /// <param name="Invoice">The invoice flag.</param>
    /// <returns>True when at least one line has a quantity to post.</returns>
    internal procedure CheckSomethingToPost(var Argument: Record "Message Argument ori"; Header: Record "Service Header"; Ship: Boolean; Consume: Boolean; Invoice: Boolean): Boolean
    var
        Line: Record "Service Line";
        NothingErr: Label 'There is nothing to post on service order %1 for these options.', Comment = '%1 = order number, is-IS=Ekkert er til að bóka á þjónustupöntun %1 fyrir þessa valkosti.';
        NothingNextLbl: Label 'Set Qty. to Ship, Qty. to Consume or Qty. to Invoice on the lines with Data.Records.Set.', Comment = 'is-IS=Settu Qty. to Ship, Qty. to Consume eða Qty. to Invoice á línurnar með Data.Records.Set.';
    begin
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        if Ship then begin
            Line.SetFilter("Qty. to Ship", '<>0');
            if not Line.IsEmpty() then
                exit(true);
            Line.SetRange("Qty. to Ship");
        end;
        if Consume then begin
            Line.SetFilter("Qty. to Consume", '<>0');
            if not Line.IsEmpty() then
                exit(true);
            Line.SetRange("Qty. to Consume");
        end;
        if Invoice and not Ship then begin
            Line.SetFilter("Qty. to Invoice", '<>0');
            if not Line.IsEmpty() then
                exit(true);
        end;
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NothingErr, Header."No."), 'lines', '', '', NothingNextLbl);
        exit(false);
    end;

    /// <summary>Returns the localized option description used in the confirmation summary.</summary>
    internal procedure OptionName(Ship: Boolean; Consume: Boolean; Invoice: Boolean): Text
    var
        ShipLbl: Label 'ship', Comment = 'is-IS=afhenda';
        InvoiceLbl: Label 'invoice', Comment = 'is-IS=reikningsfæra';
        ShipInvoiceLbl: Label 'ship and invoice', Comment = 'is-IS=afhenda og reikningsfæra';
        ShipConsumeLbl: Label 'ship and consume', Comment = 'is-IS=afhenda og nota';
    begin
        if Consume then
            exit(ShipConsumeLbl);
        if Ship and Invoice then
            exit(ShipInvoiceLbl);
        if Ship then
            exit(ShipLbl);
        exit(InvoiceLbl);
    end;

    /// <summary>Returns the option tokens in the request language independent form.</summary>
    internal procedure OptionToken(Ship: Boolean; Consume: Boolean; Invoice: Boolean): Text
    begin
        if Consume then
            exit('ship+consume');
        if Ship and Invoice then
            exit('ship+invoice');
        if Ship then
            exit('ship');
        exit('invoice');
    end;

    /// <summary>Captures the numbers of the posted shipments and invoices the order already has.</summary>
    internal procedure CapturePosted(OrderNo: Code[20]; var Shipments: List of [Code[20]]; var Invoices: List of [Code[20]]; var LastLedgerEntryNo: Integer)
    var
        ShipmentHeader: Record "Service Shipment Header";
        InvoiceHeader: Record "Service Invoice Header";
        LedgerEntry: Record "Service Ledger Entry";
    begin
        Clear(Shipments);
        Clear(Invoices);
        ShipmentHeader.SetRange("Order No.", OrderNo);
        ShipmentHeader.SetLoadFields("No.", "Order No.");
        if ShipmentHeader.FindSet() then
            repeat
                Shipments.Add(ShipmentHeader."No.");
            until ShipmentHeader.Next() = 0;
        InvoiceHeader.SetRange("Order No.", OrderNo);
        InvoiceHeader.SetLoadFields("No.", "Order No.");
        if InvoiceHeader.FindSet() then
            repeat
                Invoices.Add(InvoiceHeader."No.");
            until InvoiceHeader.Next() = 0;
        LedgerEntry.SetLoadFields("Entry No.");
        if LedgerEntry.FindLast() then
            LastLedgerEntryNo := LedgerEntry."Entry No."
        else
            LastLedgerEntryNo := 0;
    end;

    /// <summary>Lists the posted documents created since CapturePosted.</summary>
    internal procedure CollectPosted(OrderNo: Code[20]; Shipments: List of [Code[20]]; Invoices: List of [Code[20]]; var Posted: JsonArray)
    var
        ShipmentHeader: Record "Service Shipment Header";
        InvoiceHeader: Record "Service Invoice Header";
        CustLedgerEntry: Record "Cust. Ledger Entry";
        Entry: JsonObject;
    begin
        ShipmentHeader.SetRange("Order No.", OrderNo);
        if ShipmentHeader.FindSet() then
            repeat
                if not Shipments.Contains(ShipmentHeader."No.") then begin
                    Clear(Entry);
                    Entry.Add('type', 'Service Shipment');
                    Entry.Add('no', ShipmentHeader."No.");
                    Entry.Add('recordSystemId', Format(ShipmentHeader.SystemId, 0, 4));
                    Entry.Add('postingDate', Format(ShipmentHeader."Posting Date", 0, 9));
                    Posted.Add(Entry);
                end;
            until ShipmentHeader.Next() = 0;
        InvoiceHeader.SetRange("Order No.", OrderNo);
        if InvoiceHeader.FindSet() then
            repeat
                if not Invoices.Contains(InvoiceHeader."No.") then begin
                    InvoiceHeader.CalcFields(Amount, "Amount Including VAT");
                    Clear(Entry);
                    Entry.Add('type', 'Service Invoice');
                    Entry.Add('no', InvoiceHeader."No.");
                    Entry.Add('recordSystemId', Format(InvoiceHeader.SystemId, 0, 4));
                    Entry.Add('postingDate', Format(InvoiceHeader."Posting Date", 0, 9));
                    Entry.Add('amount', InvoiceHeader.Amount);
                    Entry.Add('amountIncludingVAT', InvoiceHeader."Amount Including VAT");
                    CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Invoice);
                    CustLedgerEntry.SetRange("Document No.", InvoiceHeader."No.");
                    CustLedgerEntry.SetLoadFields("Entry No.");
                    if CustLedgerEntry.FindFirst() then
                        Entry.Add('custLedgerEntryNo', CustLedgerEntry."Entry No.");
                    Posted.Add(Entry);
                end;
            until InvoiceHeader.Next() = 0;
    end;

    /// <summary>Counts the service ledger entries created for the order since CapturePosted.</summary>
    internal procedure CountLedgerEntries(OrderNo: Code[20]; LastEntryNo: Integer): Integer
    var
        LedgerEntry: Record "Service Ledger Entry";
    begin
        LedgerEntry.SetFilter("Entry No.", '>%1', LastEntryNo);
        LedgerEntry.SetRange("Service Order No.", OrderNo);
        exit(LedgerEntry.Count());
    end;

    /// <summary>Describes the remaining quantities of the order lines.</summary>
    internal procedure BuildLines(Header: Record "Service Header"; var Lines: JsonArray)
    var
        Line: Record "Service Line";
        Entry: JsonObject;
    begin
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        if Line.FindSet() then
            repeat
                Clear(Entry);
                Entry.Add('lineNo', Line."Line No.");
                Entry.Add('type', Format(Line.Type, 0, 9));
                Entry.Add('no', Line."No.");
                Entry.Add('quantity', Line.Quantity);
                Entry.Add('quantityShipped', Line."Quantity Shipped");
                Entry.Add('quantityConsumed', Line."Quantity Consumed");
                Entry.Add('quantityInvoiced', Line."Quantity Invoiced");
                Lines.Add(Entry);
            until Line.Next() = 0;
    end;

    local procedure ReadFlag(Request: JsonObject; KeyName: Text; var Sent: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Sent := false;
        if not Request.Get(KeyName, Token) then
            exit(false);
        Sent := true;
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        if Raw = 'true' then
            exit(true);
        if Raw = 'false' then
            exit(false);
        BadFlags.Add(KeyName + '|' + Raw);
        exit(false);
    end;
}
