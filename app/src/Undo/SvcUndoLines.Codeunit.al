namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Item;
using Origo.Bifrost;

/// <summary>
/// Shared validation, line selection, undo and response for Service.Shipment.Undo and Service.Consumption.Undo.
/// Every requested line is validated before anything is posted. Lines whose shipment created service items are
/// refused, because the standard undo would delete those service items (Gunnar 20.11.2026, no deletes).
/// </summary>
codeunit 10076091 "Svc Undo Lines ori"
{
    Access = Internal;

    var
        MissingLbl: Label 'Send documentNo, systemId or a plain subject with the posted service shipment number.', Comment = 'is-IS=Sendu documentNo, systemId eða númer bókuðu þjónustuafhendingarinnar í subject.';
        InvalidLbl: Label '%1 must be a nonempty JSON string of at most %2 characters.', Comment = '%1 = parameter, %2 = maximum length, is-IS=%1 verður að vera JSON-strengur sem er ekki tómur og er að hámarki %2 stafir.';
        GuidLbl: Label 'systemId must be a nonempty GUID.', Comment = 'is-IS=systemId verður að vera gilt GUID sem er ekki tómt.';
        CorrectLbl: Label 'Send the parameter in the format documented by describe_message_type.', Comment = 'is-IS=Sendu færibreytuna á sniðinu sem describe_message_type lýsir.';
        NothingLbl: Label 'Nothing was posted.', Comment = 'is-IS=Ekkert var bókað.';
        NotFoundLbl: Label 'Posted service shipment %1 was not found.', Comment = '%1 = identifier, is-IS=Bókuð þjónustuafhending %1 fannst ekki.';
        LookupLbl: Label 'Read the posted service shipments with Data.Records.Get (table Service Shipment Header) and send an existing number.', Comment = 'is-IS=Lestu bókaðar þjónustuafhendingar með Data.Records.Get (tafla Service Shipment Header) og sendu númer sem er til.';
        ConflictLbl: Label 'The identifiers do not identify the same posted service shipment.', Comment = 'is-IS=Auðkennin vísa ekki á sömu bókuðu þjónustuafhendinguna.';
        ConflictNextLbl: Label 'Send identifiers belonging to the same posted service shipment.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sömu bókuðu þjónustuafhendingunni.';
        LineNosLbl: Label 'lineNos must be a JSON array of 1 to 200 distinct positive whole line numbers.', Comment = 'is-IS=lineNos verður að vera JSON-fylki með 1 til 200 ólíkum jákvæðum heiltölum línunúmera.';
        LineNotFoundLbl: Label 'Line %1 was not found on posted service shipment %2.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 fannst ekki á bókuðu þjónustuafhendingunni %2.';
        LineLookupLbl: Label 'Read the lines with Data.Records.Get (table Service Shipment Line, Document No. = %1) and send their Line No.', Comment = '%1 = shipment number, is-IS=Lestu línurnar með Data.Records.Get (tafla Service Shipment Line, Document No. = %1) og sendu Line No. þeirra.';
        CorrectionLbl: Label 'Line %1 of posted service shipment %2 is a correction line or was already undone.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 á bókuðu þjónustuafhendingunni %2 er leiðréttingarlína eða hefur þegar verið afturkölluð.';
        CorrectionNextLbl: Label 'Send only original lines (Correction = false) that have not been undone.', Comment = 'is-IS=Sendu aðeins upprunalegar línur (Correction = false) sem hafa ekki verið afturkallaðar.';
        NoQuantityLbl: Label 'Line %1 of posted service shipment %2 has no quantity to undo.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 á bókuðu þjónustuafhendingunni %2 hefur ekkert magn til að afturkalla.';
        NoQuantityNextLbl: Label 'Send a line with a shipped quantity.', Comment = 'is-IS=Sendu línu með afhentu magni.';
        InvoicedLbl: Label 'Line %1 of posted service shipment %2 has been invoiced and cannot be undone.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 á bókuðu þjónustuafhendingunni %2 hefur verið reikningsfærð og ekki er hægt að afturkalla hana.';
        InvoicedNextLbl: Label 'Correct an invoiced line with a service credit memo in Business Central. Nothing was posted.', Comment = 'is-IS=Leiðréttu reikningsfærða línu með kreditreikningi þjónustu í Business Central. Ekkert var bókað.';
        ConsumedLbl: Label 'Line %1 of posted service shipment %2 has consumed quantity.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 á bókuðu þjónustuafhendingunni %2 hefur notað magn.';
        ConsumedNextLbl: Label 'Undo the consumption first with Service.Consumption.Undo. Nothing was posted.', Comment = 'is-IS=Afturkallaðu fyrst notkunina með Service.Consumption.Undo. Ekkert var bókað.';
        NotConsumedLbl: Label 'Line %1 of posted service shipment %2 has no consumed quantity.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 á bókuðu þjónustuafhendingunni %2 hefur ekkert notað magn.';
        NotConsumedNextLbl: Label 'Undo a shipped line that was not consumed with Service.Shipment.Undo.', Comment = 'is-IS=Afturkallaðu afhenta línu sem var ekki notuð með Service.Shipment.Undo.';
        OrderLineLbl: Label 'The service order line of line %1 (order %2) no longer exists.', Comment = '%1 = line number, %2 = service order number, is-IS=Línan á þjónustupöntuninni fyrir línu %1 (pöntun %2) er ekki lengur til.';
        OrderLineNextLbl: Label 'Correct the posted line with a service credit memo in Business Central. Nothing was posted.', Comment = 'is-IS=Leiðréttu bókuðu línuna með kreditreikningi þjónustu í Business Central. Ekkert var bókað.';
        ServiceItemLbl: Label 'Line %1 of posted service shipment %2 created service items; undoing it would delete them.', Comment = '%1 = line number, %2 = shipment number, is-IS=Lína %1 á bókuðu þjónustuafhendingunni %2 stofnaði þjónustuvörur; afturköllun hennar myndi eyða þeim.';
        ServiceItemNextLbl: Label 'Undo this line in Business Central, where you decide about the service items, or correct it with a service credit memo. Nothing was posted.', Comment = 'is-IS=Afturkallaðu þessa línu í Business Central, þar sem þú ákveður hvað verður um þjónustuvörurnar, eða leiðréttu hana með kreditreikningi þjónustu. Ekkert var bókað.';
        NoLinesLbl: Label 'Posted service shipment %1 has no line that can be undone.', Comment = '%1 = shipment number, is-IS=Bókuð þjónustuafhending %1 hefur enga línu sem hægt er að afturkalla.';
        NoLinesNextLbl: Label 'Read the lines with Data.Records.Get (table Service Shipment Line) and send lineNos for the lines you want to undo.', Comment = 'is-IS=Lestu línurnar með Data.Records.Get (tafla Service Shipment Line) og sendu lineNos fyrir línurnar sem á að afturkalla.';

    /// <summary>True when the argument runs Service.Consumption.Undo.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <returns>True for consumption undo.</returns>
    internal procedure IsConsumption(var Argument: Record "Message Argument ori"): Boolean
    begin
        exit(Argument.Type = "Message Type ori"::"Service.Consumption.Undo");
    end;

    /// <summary>Resolves the posted shipment and marks the lines to undo; answers a refusal and returns false when any line is refused.</summary>
    /// <param name="Argument">The message argument; receives the refusal.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    /// <param name="Header">The resolved posted service shipment.</param>
    /// <param name="Lines">Marked lines to undo, filtered to MarkedOnly.</param>
    /// <returns>True when at least one line can be undone and no requested line is refused.</returns>
    internal procedure Select(var Argument: Record "Message Argument ori"; Consumption: Boolean; var Header: Record "Service Shipment Header"; var Lines: Record "Service Shipment Line"): Boolean
    var
        LineNos: List of [Integer];
        LineNo: Integer;
        LineNoText: Text;
    begin
        if not FindShipment(Argument, Header) then
            exit(false);
        if not ReadLineNos(Argument, LineNos) then
            exit(false);
        Lines.Reset();
        Lines.ClearMarks();
        Lines.SetRange("Document No.", Header."No.");
        if LineNos.Count() = 0 then begin
            Lines.SetRange(Correction, false);
            if Lines.FindSet() then
                repeat
                    if Problem(Lines, Consumption) = 0 then
                        Lines.Mark(true);
                until Lines.Next() = 0;
            Lines.SetRange(Correction);
            Lines.MarkedOnly(true);
            if Lines.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoLinesLbl, Header."No."), 'lineNos', '', '', NoLinesNextLbl);
                exit(false);
            end;
            exit(true);
        end;
        foreach LineNo in LineNos do begin
            LineNoText := Format(LineNo, 0, 9);
            if not Lines.Get(Header."No.", LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundLbl, LineNoText, Header."No."), 'lineNos', LineNoText, '', StrSubstNo(LineLookupLbl, Header."No."));
                exit(false);
            end;
            if Lines.Correction then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(CorrectionLbl, LineNoText, Header."No."), 'lineNos', LineNoText, 'Correction = false', CorrectionNextLbl);
                exit(false);
            end;
            if not RespondProblem(Argument, Lines, Consumption) then
                exit(false);
            Lines.Mark(true);
        end;
        Lines.MarkedOnly(true);
        exit(true);
    end;

    /// <summary>Returns the marked line numbers as a comma-separated invariant list.</summary>
    /// <param name="Lines">Marked lines.</param>
    /// <returns>For example 10000, 20000.</returns>
    internal procedure LineList(var Lines: Record "Service Shipment Line") Result: Text
    begin
        if Lines.FindSet() then
            repeat
                if Result <> '' then
                    Result += ', ';
                Result += Format(Lines."Line No.", 0, 9);
            until Lines.Next() = 0;
    end;

    /// <summary>Undoes each marked line with the standard Business Central undo and builds the success response.</summary>
    /// <param name="Header">The posted service shipment.</param>
    /// <param name="Lines">Marked, validated lines.</param>
    /// <param name="Consumption">True for consumption undo.</param>
    /// <param name="Response">The success response.</param>
    internal procedure UndoLines(Header: Record "Service Shipment Header"; var Lines: Record "Service Shipment Line"; Consumption: Boolean; var Response: JsonObject)
    var
        Line: Record "Service Shipment Line";
        ShipmentUndo: Codeunit "Undo Service Shipment Line";
        ConsumptionUndo: Codeunit "Undo Service Consumption Line";
        LineNos: List of [Integer];
        LineNo: Integer;
        Reversed: JsonArray;
        Results: JsonArray;
        Result: JsonObject;
    begin
        Lines.FindSet();
        repeat
            LineNos.Add(Lines."Line No.");
        until Lines.Next() = 0;
        foreach LineNo in LineNos do begin
            Line.Reset();
            Line.SetRange("Document No.", Header."No.");
            Line.SetRange("Line No.", LineNo);
            if Consumption then begin
                Clear(ConsumptionUndo);
                ConsumptionUndo.SetHideDialog(true);
                ConsumptionUndo.Run(Line);
            end else begin
                Clear(ShipmentUndo);
                ShipmentUndo.SetHideDialog(true);
                ShipmentUndo.Run(Line);
            end;
            Line.Get(Header."No.", LineNo);
            Reversed.Add(LineNo);
            Clear(Result);
            BuildLine(Line, Result);
            Results.Add(Result);
        end;
        Response.Add('status', 'Success');
        Response.Add('documentNo', Header."No.");
        Response.Add('serviceOrderNo', Header."Order No.");
        Response.Add('reversedLineNos', Reversed);
        Response.Add('reversedCount', LineNos.Count());
        Response.Add('lines', Results);
    end;

    local procedure BuildLine(Line: Record "Service Shipment Line"; var Result: JsonObject)
    var
        Correction: Record "Service Shipment Line";
        OrderLine: Record "Service Line";
    begin
        Result.Add('lineNo', Line."Line No.");
        Result.Add('type', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
        Result.Add('no', Line."No.");
        Result.Add('quantity', Line.Quantity);
        Correction.SetLoadFields("Document No.", "Line No.", Correction, "Order Line No.");
        Correction.SetRange("Document No.", Line."Document No.");
        Correction.SetFilter("Line No.", '>%1', Line."Line No.");
        Correction.SetRange(Correction, true);
        Correction.SetRange("Order Line No.", Line."Order Line No.");
        if Correction.FindFirst() then
            Result.Add('correctionLineNo', Correction."Line No.");
        Result.Add('orderLineNo', Line."Order Line No.");
        OrderLine.SetLoadFields(Quantity, "Quantity Shipped", "Quantity Consumed", "Outstanding Quantity", "Qty. to Ship", "Qty. to Consume");
        if not OrderLine.Get(OrderLine."Document Type"::Order, Line."Order No.", Line."Order Line No.") then
            exit;
        Result.Add('quantityShipped', OrderLine."Quantity Shipped");
        Result.Add('quantityConsumed', OrderLine."Quantity Consumed");
        Result.Add('outstandingQuantity', OrderLine."Outstanding Quantity");
        Result.Add('qtyToShip', OrderLine."Qty. to Ship");
        Result.Add('qtyToConsume', OrderLine."Qty. to Consume");
    end;

    local procedure RespondProblem(var Argument: Record "Message Argument ori"; Line: Record "Service Shipment Line"; Consumption: Boolean): Boolean
    var
        LineNoText: Text;
    begin
        LineNoText := Format(Line."Line No.", 0, 9);
        case Problem(Line, Consumption) of
            0:
                exit(true);
            1:
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoQuantityLbl, LineNoText, Line."Document No."), 'lineNos', LineNoText, '', NoQuantityNextLbl);
            2:
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(InvoicedLbl, LineNoText, Line."Document No."), 'lineNos', LineNoText, '', InvoicedNextLbl);
            3:
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ConsumedLbl, LineNoText, Line."Document No."), 'lineNos', LineNoText, '', ConsumedNextLbl);
            4:
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(OrderLineLbl, LineNoText, Line."Order No."), 'lineNos', LineNoText, '', OrderLineNextLbl);
            5:
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ServiceItemLbl, LineNoText, Line."Document No."), 'lineNos', LineNoText, '', ServiceItemNextLbl);
            6:
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotConsumedLbl, LineNoText, Line."Document No."), 'lineNos', LineNoText, '', NotConsumedNextLbl);
        end;
        exit(false);
    end;

    /// <summary>0 = can be undone; 1 = no quantity; 2 = invoiced; 3 = consumed; 4 = order line gone; 5 = created service items; 6 = nothing consumed.</summary>
    local procedure Problem(Line: Record "Service Shipment Line"; Consumption: Boolean): Integer
    var
        OrderLine: Record "Service Line";
        ServiceItem: Record "Service Item";
    begin
        if (Line.Type = Line.Type::" ") or (Line.Quantity = 0) then
            exit(1);
        if Line."Quantity Invoiced" <> 0 then
            exit(2);
        if Consumption then begin
            if Line."Quantity Consumed" = 0 then
                exit(6);
            if Line."Qty. Shipped Not Invoiced" <> Line.Quantity - Line."Quantity Consumed" then
                exit(2);
        end else begin
            if Line."Quantity Consumed" <> 0 then
                exit(3);
            if Line."Qty. Shipped Not Invoiced" <> Line.Quantity then
                exit(2);
        end;
        OrderLine.SetLoadFields("Document Type", "Document No.", "Line No.");
        if not OrderLine.Get(OrderLine."Document Type"::Order, Line."Order No.", Line."Order Line No.") then
            exit(4);
        if not Consumption then begin
            ServiceItem.SetCurrentKey("Sales/Serv. Shpt. Document No.", "Sales/Serv. Shpt. Line No.");
            ServiceItem.SetRange("Sales/Serv. Shpt. Document No.", Line."Document No.");
            ServiceItem.SetRange("Sales/Serv. Shpt. Line No.", Line."Line No.");
            ServiceItem.SetRange("Shipment Type", ServiceItem."Shipment Type"::Service);
            if not ServiceItem.IsEmpty() then
                exit(5);
        end;
        exit(0);
    end;

    local procedure FindShipment(var Argument: Record "Message Argument ori"; var Header: Record "Service Shipment Header"): Boolean
    var
        Request: JsonObject;
        Number: Text;
        IdText: Text;
        SubjectNumber: Text;
        Id: Guid;
    begin
        Request := Argument.GetRequestJson();
        Number := ReadIdentifier(Request, 'documentNo', MaxStrLen(Header."No."), Argument);
        IdText := ReadIdentifier(Request, 'systemId', 50, Argument);
        SubjectNumber := Argument.Subject.Trim();
        if StrLen(SubjectNumber) > MaxStrLen(Header."No.") then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidLbl, 'subject', MaxStrLen(Header."No.")), 'subject', '', '', CorrectLbl);
        if (Number = '') and (IdText = '') and (SubjectNumber = '') and not Argument.HasCollectedErrors() then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingLbl, 'documentNo/systemId', '', '', CorrectLbl);
        if IdText <> '' then
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, GuidLbl, 'systemId', IdText, 'GUID', CorrectLbl);
        if Argument.HasCollectedErrors() then begin
            Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, NothingLbl);
            exit(false);
        end;
        if (Number <> '') and (SubjectNumber <> '') and (UpperCase(Number) <> UpperCase(SubjectNumber)) then
            exit(Conflict(Argument));
        if Number = '' then
            Number := SubjectNumber;
        Header.Reset();
        Header.SetLoadFields("No.", "Order No.");
        if IdText <> '' then begin
            if not Header.GetBySystemId(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, IdText), 'systemId', IdText, '', LookupLbl);
                exit(false);
            end;
            if (Number <> '') and (Header."No." <> UpperCase(Number)) then
                exit(Conflict(Argument));
            exit(true);
        end;
        if not Header.Get(UpperCase(Number)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, Number), 'documentNo', Number, '', LookupLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadLineNos(var Argument: Record "Message Argument ori"; var LineNos: List of [Integer]): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Element: JsonToken;
        Raw: Text;
        LineNo: Integer;
        Number: Decimal;
    begin
        Request := Argument.GetRequestJson();
        if not Request.Get('lineNos', Token) then
            exit(true);
        if not Token.IsArray() then
            exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameterFormat));
        if (Token.AsArray().Count() < 1) or (Token.AsArray().Count() > 200) then
            exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameter));
        foreach Element in Token.AsArray() do begin
            if not Element.IsValue() then
                exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameterFormat));
            Element.WriteTo(Raw);
            if (Raw = '') or (CopyStr(Raw, 1, 1) = '"') or (Raw in ['null', 'true', 'false']) then
                exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameterFormat));
            if not Evaluate(Number, Raw, 9) then
                exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameterFormat));
            if (Number <> Round(Number, 1)) or (Number < 1) or (Number > 2147483647) then
                exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameter));
            LineNo := Number;
            if LineNos.Contains(LineNo) then
                exit(BadLineNos(Argument, "Bifrost Error Code ori"::InvalidParameter));
            LineNos.Add(LineNo);
        end;
        exit(true);
    end;

    local procedure BadLineNos(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"): Boolean
    begin
        Argument.RespondWithError(Code, LineNosLbl, 'lineNos', '', 'array', CorrectLbl);
        exit(false);
    end;

    local procedure ReadIdentifier(Request: JsonObject; KeyName: Text; Maximum: Integer; var Argument: Record "Message Argument ori"): Text
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
    begin
        if not Request.Get(KeyName, Token) then
            exit('');
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, KeyName, Maximum), KeyName, '', 'string', CorrectLbl);
            exit('');
        end;
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidLbl, KeyName, Maximum), KeyName, '', '', CorrectLbl);
        exit(Value);
    end;

    local procedure Conflict(var Argument: Record "Message Argument ori"): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'documentNo/systemId/subject', '', '', ConflictNextLbl);
        exit(false);
    end;
}
