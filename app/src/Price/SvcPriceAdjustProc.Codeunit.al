namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Finance.Currency;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Microsoft.Service.Pricing;
using Origo.Bifrost;

/// <summary>
/// Applies or resets a service price adjustment for one service item line. The working rows are temporary,
/// so the real working table is never filled or cleared. Runs through Codeunit.Run so a failure leaves nothing written.
/// </summary>
codeunit 10076141 "Svc Price Adjust Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        if ResetMode then
            ResetPrices(Rec)
        else
            AdjustPrices(Rec);
    end;

    var
        ItemLine: Record "Service Item Line";
        TempStored: Record "Service Line" temporary;
        ResetMode: Boolean;
        PreviewMode: Boolean;
        NoGroupLbl: Label 'Service item line %1 %2 has no service price group.', Comment = '%1 = document number, %2 = line number, is-IS=Þjónustuvörulína %1 %2 er ekki með þjónustuverðflokk.';
        NoGroupNextLbl: Label 'Set Service Price Group Code on the service item line with Data.Records.Set (table Service Item Line), then retry.', Comment = 'is-IS=Settu Service Price Group Code á þjónustuvörulínuna með Data.Records.Set (tafla Service Item Line) og reyndu svo aftur.';
        NoSetupLbl: Label 'Service price group %1 has no price adjustment setup for this document (adjustment group, customer price group, currency and starting date).', Comment = '%1 = service price group, is-IS=Þjónustuverðflokkur %1 er ekki með verðleiðréttingaruppsetningu sem á við þetta skjal (leiðréttingarflokkur, verðflokkur viðskiptamanns, gjaldmiðill og upphafsdagsetning).';
        NoSetupNextLbl: Label 'Add a price group setup row with an adjustment group with Data.Records.Set (table Serv. Price Group Setup), then set the service price group on the service item line again.', Comment = 'is-IS=Bættu við uppsetningarlínu verðflokks með leiðréttingarflokki með Data.Records.Set (tafla Serv. Price Group Setup) og settu svo þjónustuverðflokkinn aftur á þjónustuvörulínuna.';
        NoLinesLbl: Label 'Service item line %1 %2 has no service lines that the price adjustment group covers.', Comment = '%1 = document number, %2 = line number, is-IS=Þjónustuvörulína %1 %2 er ekki með neinar þjónustulínur sem verðleiðréttingarflokkurinn nær yfir.';
        NoLinesNextLbl: Label 'Add item, resource, cost or G/L account lines to the service item line with Data.Records.Set (table Service Line), or check the adjustment group details.', Comment = 'is-IS=Bættu vöru-, forða-, kostnaðar- eða fjárhagslykilslínum við þjónustuvörulínuna með Data.Records.Set (tafla Service Line), eða athugaðu nánari upplýsingar leiðréttingarflokksins.';
        InvoicedLbl: Label 'Service line %1 on %2 is already invoiced, so its price cannot be adjusted.', Comment = '%1 = line number, %2 = document number, is-IS=Þjónustulína %1 á %2 hefur þegar verið reikningsfærð og því er ekki hægt að leiðrétta verð hennar.';
        InvoicedNextLbl: Label 'Adjust prices only before invoicing. Correct invoiced amounts with a service credit memo.', Comment = 'is-IS=Leiðréttu verð aðeins fyrir reikningsfærslu. Leiðréttu reikningsfærðar upphæðir með kreditreikningi þjónustu.';
        NothingResetLbl: Label 'Service item line %1 %2 has no adjusted service lines to reset.', Comment = '%1 = document number, %2 = line number, is-IS=Þjónustuvörulína %1 %2 er ekki með neinar leiðréttar þjónustulínur til að endurstilla.';
        NothingResetNextLbl: Label 'Nothing to do. Send reset only after a price adjustment.', Comment = 'is-IS=Ekkert að gera. Sendu reset aðeins eftir verðleiðréttingu.';

    /// <summary>Sets the service item line and the mode before Codeunit.Run.</summary>
    internal procedure SetRequest(NewItemLine: Record "Service Item Line"; NewPreview: Boolean; NewReset: Boolean)
    begin
        ItemLine := NewItemLine;
        PreviewMode := NewPreview;
        ResetMode := NewReset;
    end;

    local procedure AdjustPrices(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        Setup: Record "Serv. Price Group Setup";
        TempAdjmt: Record "Service Line Price Adjmt." temporary;
        Currency: Record Currency;
        PriceManagement: Codeunit "Service Price Management";
        Total: Decimal;
        StoredTotal: Decimal;
        Apply: Boolean;
        DiscountsRemoved: Boolean;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        if not LockLine(Header) then
            exit;
        if ItemLine."Service Price Group Code" = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoGroupLbl, ItemLine."Document No.", ItemLine."Line No."), 'serviceItemLineNo', '', '', NoGroupNextLbl);
            exit;
        end;
        PriceManagement.GetServPriceGrSetup(Setup, Header, ItemLine);
        if (Setup."Service Price Group Code" = '') or (ItemLine."Serv. Price Adjmt. Gr. Code" = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoSetupLbl, ItemLine."Service Price Group Code"), 'serviceItemLineNo', '', '', NoSetupNextLbl);
            exit;
        end;
        InitCurrency(Header, Currency);
        if not BuildWorkingRows(Argument, Header, Setup, TempAdjmt, DiscountsRemoved) then
            exit;

        // Compare in the setup's tax basis: a VAT-exclusive target is compared with net amounts, also on a prices-including-VAT document.
        Total := CalculationTotal(TempAdjmt, Header, Setup, Currency);
        StoredTotal := StoredBasisTotal(Header, Setup, Currency);
        case Setup."Adjustment Type" of
            Setup."Adjustment Type"::Fixed:
                Apply := true;
            Setup."Adjustment Type"::Maximum:
                Apply := Total > Setup.Amount;
            Setup."Adjustment Type"::Minimum:
                Apply := Total < Setup.Amount;
        end;
        if Apply then
            Spread(TempAdjmt, Setup, Header, Currency, Total);
        if Apply and not PreviewMode then
            ApplyRows(TempAdjmt, Header, Setup."Include VAT");

        if TempAdjmt.FindSet() then
            repeat
                Lines.Add(LineEntry(TempAdjmt, Apply));
            until TempAdjmt.Next() = 0;
        Response := HeaderEntry(Header, PreviewMode, 'adjust');
        Response.Add('adjustmentGroupCode', ItemLine."Serv. Price Adjmt. Gr. Code");
        Response.Add('adjustmentType', TypeName(Setup));
        Response.Add('targetAmount', Setup.Amount);
        Response.Add('includeVAT', Setup."Include VAT");
        Response.Add('includeDiscounts', Setup."Include Discounts");
        Response.Add('discountsRemoved', DiscountsRemoved and Apply);
        Response.Add('totalBefore', StoredTotal);
        Response.Add('comparedTotal', Total);
        if Apply then
            Response.Add('totalAfter', NewTotal(TempAdjmt, Header, Setup, Currency))
        else
            Response.Add('totalAfter', StoredTotal);
        Response.Add('changed', Apply and not PreviewMode);
        Response.Add('lines', Lines);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ResetPrices(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        TempBefore: Record "Service Line" temporary;
        PriceManagement: Codeunit "Service Price Management";
        Entry: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        if not LockLine(Header) then
            exit;
        FilterLines(Line);
        Line.SetRange("Price Adjmt. Status", Line."Price Adjmt. Status"::Adjusted);
        if not Line.FindSet() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NothingResetLbl, ItemLine."Document No.", ItemLine."Line No."), 'reset', '', '', NothingResetNextLbl);
            exit;
        end;
        repeat
            if Line."Quantity Invoiced" <> 0 then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(InvoicedLbl, Line."Line No.", Line."Document No."), 'reset', '', '', InvoicedNextLbl);
                exit;
            end;
            TempBefore := Line;
            TempBefore.Insert();
        until Line.Next() = 0;
        if not PreviewMode then
            PriceManagement.ResetAdjustedLines(Line);
        if TempBefore.FindSet() then
            repeat
                Line.Get(TempBefore."Document Type", TempBefore."Document No.", TempBefore."Line No.");
                Clear(Entry);
                Entry.Add('lineNo', Line."Line No.");
                Entry.Add('type', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
                Entry.Add('no', Line."No.");
                Entry.Add('oldUnitPrice', TempBefore."Unit Price");
                Entry.Add('newUnitPrice', Line."Unit Price");
                Entry.Add('oldAmount', TempBefore."Line Amount");
                Entry.Add('newAmount', Line."Line Amount");
                Entry.Add('status', StatusName(Line));
                Lines.Add(Entry);
            until TempBefore.Next() = 0;
        Response := HeaderEntry(Header, PreviewMode, 'reset');
        Response.Add('changed', not PreviewMode);
        Response.Add('lines', Lines);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure LockLine(var Header: Record "Service Header"): Boolean
    begin
        if not PreviewMode then begin
            Header.ReadIsolation := IsolationLevel::UpdLock;
            ItemLine.ReadIsolation := IsolationLevel::UpdLock;
        end;
        ItemLine.Get(ItemLine."Document Type", ItemLine."Document No.", ItemLine."Line No.");
        Header.Get(ItemLine."Document Type", ItemLine."Document No.");
        exit(true);
    end;

    local procedure FilterLines(var Line: Record "Service Line")
    begin
        Line.SetCurrentKey("Document Type", "Document No.", "Service Item Line No.");
        Line.SetRange("Document Type", ItemLine."Document Type");
        Line.SetRange("Document No.", ItemLine."Document No.");
        Line.SetRange("Service Item Line No.", ItemLine."Line No.");
    end;

    /// <summary>Fills temporary working rows the way the standard price adjustment page does, without the page and without the real working table.</summary>
    local procedure BuildWorkingRows(var Argument: Record "Message Argument ori"; Header: Record "Service Header"; Setup: Record "Serv. Price Group Setup"; var TempAdjmt: Record "Service Line Price Adjmt." temporary; var DiscountsRemoved: Boolean): Boolean
    var
        Line: Record "Service Line";
        Stored: Record "Service Line";
        Currency: Record Currency;
    begin
        InitCurrency(Header, Currency);
        FilterLines(Line);
        if Line.FindSet() then
            repeat
                if Covered(Line, ItemLine."Serv. Price Adjmt. Gr. Code") then begin
                    if Line."Quantity Invoiced" <> 0 then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(InvoicedLbl, Line."Line No.", Line."Document No."), 'serviceItemLineNo', '', '', InvoicedNextLbl);
                        exit(false);
                    end;
                    // Keep the stored line apart from the calculation basis, so responses always report what is on the document.
                    Stored := Line;
                    TempAdjmt.Init();
                    TempAdjmt."Vat %" := Line."VAT %";
                    if Header."Prices Including VAT" then
                        Line."VAT %" := 0;
                    // The calculation runs on an in-memory copy of the line; only ApplyRows writes.
                    if not Setup."Include Discounts" and (Line."Line Discount %" <> 0) then begin
                        Line.Validate("Line Discount %", 0);
                        DiscountsRemoved := true;
                    end;
                    TempAdjmt."Document Type" := Line."Document Type";
                    TempAdjmt."Document No." := Line."Document No.";
                    TempAdjmt."Service Line No." := Line."Line No.";
                    TempAdjmt."Service Item Line No." := Line."Service Item Line No.";
                    TempAdjmt."Service Item No." := Line."Service Item No.";
                    TempAdjmt."Serv. Price Adjmt. Gr. Code" := ItemLine."Serv. Price Adjmt. Gr. Code";
                    TempAdjmt.Type := Line.Type;
                    TempAdjmt."No." := Line."No.";
                    TempAdjmt.Description := Line.Description;
                    TempAdjmt.Quantity := Line.Quantity - Line."Quantity Consumed" - Line."Qty. to Consume";
                    TempAdjmt.Amount := Line."Line Amount";
                    TempAdjmt."New Amount" := Line."Line Amount";
                    TempAdjmt."Unit Price" := Line."Unit Price";
                    TempAdjmt."New Unit Price" := Line."Unit Price";
                    TempAdjmt."Unit Cost" := Line."Unit Cost";
                    TempAdjmt."Discount %" := Line."Line Discount %";
                    TempAdjmt."Discount Amount" := Line."Line Discount Amount";
                    TempAdjmt."Amount incl. VAT" := Line."Amount Including VAT";
                    TempAdjmt."New Amount incl. VAT" := Line."Amount Including VAT";
                    TempAdjmt."New Amount Excl. VAT" := Round(Line."Amount Including VAT" / (1 + TempAdjmt."Vat %" / 100), Currency."Amount Rounding Precision");
                    TempAdjmt."Adjustment Type" := Setup."Adjustment Type";
                    TempAdjmt."Service Price Group Code" := ItemLine."Service Price Group Code";
                    // A line with nothing left to consume cannot carry a new unit price.
                    if TempAdjmt.Quantity > 0 then begin
                        TempAdjmt.Insert();
                        TempStored := Stored;
                        TempStored.Insert();
                    end;
                end;
            until Line.Next() = 0;
        if TempAdjmt.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoLinesLbl, ItemLine."Document No.", ItemLine."Line No."), 'serviceItemLineNo', '', '', NoLinesNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Decides whether a service line falls under the adjustment group, following the standard group detail rules.</summary>
    local procedure Covered(Line: Record "Service Line"; GroupCode: Code[10]): Boolean
    var
        Resource: Record Resource;
        Detail: Record "Serv. Price Adjustment Detail";
    begin
        if (Line.Type = Line.Type::" ") or Line.Warranty then
            exit(false);
        Detail.SetRange("Serv. Price Adjmt. Gr. Code", GroupCode);
        if Detail.IsEmpty() then
            exit(true);
        case Line.Type of
            Line.Type::Item:
                Detail.SetRange(Type, Detail.Type::Item);
            Line.Type::Resource:
                Detail.SetRange(Type, Detail.Type::Resource);
            Line.Type::Cost:
                Detail.SetRange(Type, Detail.Type::"Service Cost");
            Line.Type::"G/L Account":
                Detail.SetRange(Type, Detail.Type::"G/L Account");
            else
                exit(false);
        end;
        Detail.SetFilter("No.", '%1|%2', Line."No.", '');
        Detail.SetFilter("Work Type", '%1|%2', Line."Work Type Code", '');
        Detail.SetFilter("Gen. Prod. Posting Group", '%1|%2', Line."Gen. Prod. Posting Group", '');
        if not Detail.IsEmpty() then
            exit(true);
        if Line.Type <> Line.Type::Resource then
            exit(false);
        Resource.SetLoadFields("Resource Group No.");
        if not Resource.Get(Line."No.") then
            exit(false);
        Detail.SetRange(Type, Detail.Type::"Resource Group");
        Detail.SetFilter("No.", '%1|%2', Resource."Resource Group No.", '');
        exit(not Detail.IsEmpty());
    end;

    /// <summary>Spreads the target amount over the working rows by weight; the last row takes the rounding difference so the lines add up to the target.</summary>
    local procedure Spread(var TempAdjmt: Record "Service Line Price Adjmt." temporary; Setup: Record "Serv. Price Group Setup"; Header: Record "Service Header"; Currency: Record Currency; Total: Decimal)
    var
        Target: Decimal;
        Share: Decimal;
        Assigned: Decimal;
        Remaining: Integer;
    begin
        Assigned := 0;
        Remaining := TempAdjmt.Count();
        TempAdjmt.FindSet();
        repeat
            Remaining -= 1;
            if Total <> 0 then
                TempAdjmt.Weight := Round(TaxBasis(Header, Setup, Currency, TempAdjmt.Amount, TempAdjmt."Amount incl. VAT", TempAdjmt."Vat %") * 100 / Total, 0.00001);
            Target := Setup.Amount;
            if Header."Prices Including VAT" and not Setup."Include VAT" then
                Target := Round(Target + Target * TempAdjmt."Vat %" / 100, 0.00001);
            Share := Round(Target * TempAdjmt.Weight / 100, Currency."Amount Rounding Precision");
            if (Remaining = 0) and not (Header."Prices Including VAT" and not Setup."Include VAT") then
                Share := Target - Assigned;
            Assigned += Share;
            if Setup."Include VAT" then
                TempAdjmt.Validate("New Amount incl. VAT", Share)
            else
                TempAdjmt.Validate("New Amount", Share);
            TempAdjmt.Modify();
        until TempAdjmt.Next() = 0;
    end;

    /// <summary>Writes the new prices to the service lines and marks them adjusted, so the standard reset can restore them.</summary>
    local procedure ApplyRows(var TempAdjmt: Record "Service Line Price Adjmt." temporary; Header: Record "Service Header"; InclVat: Boolean)
    var
        Line: Record "Service Line";
        OldVatPct: Decimal;
    begin
        TempAdjmt.FindSet();
        repeat
            Line.Get(TempAdjmt."Document Type", TempAdjmt."Document No.", TempAdjmt."Service Line No.");
            if Header."Prices Including VAT" then begin
                OldVatPct := Line."VAT %";
                Line."VAT %" := 0;
            end;
            Line.Validate("Unit Price", TempAdjmt."New Unit Price");
            if TempAdjmt."Discount %" = 0 then
                Line.Validate("Line Discount %", 0);
            if TempAdjmt."New Amount incl. VAT" <> 0 then begin
                if InclVat then
                    Line.Validate("Amount Including VAT", TempAdjmt."New Amount incl. VAT")
                else
                    Line.Validate("Line Amount", TempAdjmt."New Amount");
            end else
                Line.Validate("Unit Price", 0);
            Line."Price Adjmt. Status" := Line."Price Adjmt. Status"::Adjusted;
            if Header."Prices Including VAT" then
                Line."VAT %" := OldVatPct;
            Line.Modify();
        until TempAdjmt.Next() = 0;
    end;

    /// <summary>Returns an amount in the setup's tax basis: including VAT when the setup includes VAT, otherwise excluding VAT, whatever the document's Prices Including VAT.</summary>
    local procedure TaxBasis(Header: Record "Service Header"; Setup: Record "Serv. Price Group Setup"; Currency: Record Currency; LineAmount: Decimal; AmountInclVAT: Decimal; VatPct: Decimal): Decimal
    begin
        if Setup."Include VAT" then
            exit(AmountInclVAT);
        if Header."Prices Including VAT" then
            exit(Round(LineAmount / (1 + VatPct / 100), Currency."Amount Rounding Precision"));
        exit(LineAmount);
    end;

    local procedure CalculationTotal(var TempAdjmt: Record "Service Line Price Adjmt." temporary; Header: Record "Service Header"; Setup: Record "Serv. Price Group Setup"; Currency: Record Currency) Total: Decimal
    begin
        if TempAdjmt.FindSet() then
            repeat
                Total += TaxBasis(Header, Setup, Currency, TempAdjmt.Amount, TempAdjmt."Amount incl. VAT", TempAdjmt."Vat %");
            until TempAdjmt.Next() = 0;
    end;

    local procedure NewTotal(var TempAdjmt: Record "Service Line Price Adjmt." temporary; Header: Record "Service Header"; Setup: Record "Serv. Price Group Setup"; Currency: Record Currency) Total: Decimal
    begin
        if TempAdjmt.FindSet() then
            repeat
                Total += TaxBasis(Header, Setup, Currency, TempAdjmt."New Amount", TempAdjmt."New Amount incl. VAT", TempAdjmt."Vat %");
            until TempAdjmt.Next() = 0;
    end;

    local procedure StoredBasisTotal(Header: Record "Service Header"; Setup: Record "Serv. Price Group Setup"; Currency: Record Currency) Total: Decimal
    begin
        if TempStored.FindSet() then
            repeat
                Total += TaxBasis(Header, Setup, Currency, TempStored."Line Amount", TempStored."Amount Including VAT", TempStored."VAT %");
            until TempStored.Next() = 0;
    end;

    local procedure InitCurrency(Header: Record "Service Header"; var Currency: Record Currency)
    begin
        if Header."Currency Code" = '' then
            Currency.InitRoundingPrecision()
        else
            Currency.Get(Header."Currency Code");
    end;

    local procedure LineEntry(TempAdjmt: Record "Service Line Price Adjmt." temporary; Applied: Boolean): JsonObject
    var
        Line: Record "Service Line";
        Entry: JsonObject;
    begin
        Entry.Add('lineNo', TempAdjmt."Service Line No.");
        Entry.Add('type', TempAdjmt.Type.Names().Get(TempAdjmt.Type.Ordinals().IndexOf(TempAdjmt.Type.AsInteger())));
        Entry.Add('no', TempAdjmt."No.");
        Entry.Add('description', TempAdjmt.Description);
        Entry.Add('quantity', TempAdjmt.Quantity);
        Entry.Add('weight', TempAdjmt.Weight);
        TempStored.Get(TempAdjmt."Document Type", TempAdjmt."Document No.", TempAdjmt."Service Line No.");
        Entry.Add('oldUnitPrice', TempStored."Unit Price");
        Entry.Add('oldAmount', TempStored."Line Amount");
        if not Applied then begin
            // Nothing is written, so the new values are the stored ones.
            Entry.Add('newUnitPrice', TempStored."Unit Price");
            Entry.Add('newAmount', TempStored."Line Amount");
            Entry.Add('status', StatusName(TempStored));
            exit(Entry);
        end;
        if not PreviewMode then begin
            Line.SetLoadFields("Unit Price", "Line Amount", "Price Adjmt. Status");
            Line.Get(TempAdjmt."Document Type", TempAdjmt."Document No.", TempAdjmt."Service Line No.");
            Entry.Add('newUnitPrice', Line."Unit Price");
            Entry.Add('newAmount', Line."Line Amount");
            Entry.Add('status', StatusName(Line));
        end else begin
            Entry.Add('newUnitPrice', TempAdjmt."New Unit Price");
            Entry.Add('newAmount', TempAdjmt."New Amount");
            Line.SetLoadFields("Price Adjmt. Status");
            Line.Get(TempAdjmt."Document Type", TempAdjmt."Document No.", TempAdjmt."Service Line No.");
            Entry.Add('status', StatusName(Line));
        end;
        exit(Entry);
    end;

    local procedure HeaderEntry(Header: Record "Service Header"; Preview: Boolean; Mode: Text): JsonObject
    var
        Response: JsonObject;
    begin
        Response.Add('status', 'Success');
        Response.Add('mode', Mode);
        Response.Add('preview', Preview);
        Response.Add('documentType', Header."Document Type".Names().Get(Header."Document Type".Ordinals().IndexOf(Header."Document Type".AsInteger())));
        Response.Add('documentNo', Header."No.");
        Response.Add('serviceItemLineNo', ItemLine."Line No.");
        Response.Add('servicePriceGroupCode', ItemLine."Service Price Group Code");
        exit(Response);
    end;

    local procedure TypeName(Setup: Record "Serv. Price Group Setup"): Text
    begin
        case Setup."Adjustment Type" of
            Setup."Adjustment Type"::Maximum:
                exit('Maximum');
            Setup."Adjustment Type"::Minimum:
                exit('Minimum');
        end;
        exit('Fixed');
    end;

    local procedure StatusName(Line: Record "Service Line"): Text
    begin
        case Line."Price Adjmt. Status" of
            Line."Price Adjmt. Status"::Adjusted:
                exit('Adjusted');
            Line."Price Adjmt. Status"::Modified:
                exit('Modified');
        end;
        exit('None');
    end;
}
