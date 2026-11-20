namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.History;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Creates posted service shipments from self-made orders and sends undo requests for the undo tests.</summary>
codeunit 97754 "Svc Undo Data ori"
{
    var
        PostData: Codeunit "Svc Post Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Creates an order (item line 2, resource line 3), optionally consumes 1 of each line (so the order line stays), and posts the shipment.</summary>
    /// <param name="Header">The created order.</param>
    /// <param name="Consume">True to post Ship and Consume.</param>
    /// <returns>The posted service shipment number.</returns>
    procedure ShipOrder(var Header: Record "Service Header"; Consume: Boolean): Code[20]
    var
        Line: Record "Service Line";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        if Consume then begin
            Line.SetRange("Document Type", Header."Document Type");
            Line.SetRange("Document No.", Header."No.");
            Line.FindSet(true);
            repeat
                Line.Validate("Qty. to Consume", 1);
                Line.Modify(true);
            until Line.Next() = 0;
        end;
        Commit();
        if Consume then
            Response := PostData.Post(Header."No.", 'true', 'true', '', 1, 1033)
        else
            Response := PostData.Post(Header."No.", 'true', '', '', 1, 1033);
        PostData.AssertSuccess(Response);
        exit(FindShipment(Header."No."));
    end;

    /// <summary>Returns the last posted service shipment of an order.</summary>
    /// <param name="OrderNo">The service order.</param>
    /// <returns>The shipment number.</returns>
    procedure FindShipment(OrderNo: Code[20]): Code[20]
    var
        ShipmentHeader: Record "Service Shipment Header";
    begin
        ShipmentHeader.SetRange("Order No.", OrderNo);
        ShipmentHeader.FindLast();
        exit(ShipmentHeader."No.");
    end;

    /// <summary>Returns the first original shipment line of the given type.</summary>
    /// <param name="ShipmentNo">The posted shipment.</param>
    /// <param name="LineType">Item or Resource.</param>
    /// <param name="ShipmentLine">The line found.</param>
    procedure FindLine(ShipmentNo: Code[20]; LineType: Enum "Service Line Type"; var ShipmentLine: Record "Service Shipment Line")
    begin
        ShipmentLine.Reset();
        ShipmentLine.SetRange("Document No.", ShipmentNo);
        ShipmentLine.SetRange(Type, LineType);
        ShipmentLine.SetRange(Correction, false);
        ShipmentLine.FindFirst();
    end;

    /// <summary>Builds an undo request; LineNos empty omits lineNos, Count 0 omits expectedCount.</summary>
    /// <param name="ShipmentNo">The posted shipment.</param>
    /// <param name="LineNos">Line numbers to undo.</param>
    /// <param name="Count">expectedCount, or 0.</param>
    /// <returns>The request.</returns>
    procedure Build(ShipmentNo: Code[20]; LineNos: List of [Integer]; Count: Integer) Request: JsonObject
    var
        Numbers: JsonArray;
        LineNo: Integer;
    begin
        Request.Add('documentNo', ShipmentNo);
        if LineNos.Count() > 0 then begin
            foreach LineNo in LineNos do
                Numbers.Add(LineNo);
            Request.Add('lineNos', Numbers);
        end;
        if Count > 0 then
            Request.Add('expectedCount', Count);
    end;

    /// <summary>Sends Service.Shipment.Undo or Service.Consumption.Undo.</summary>
    /// <param name="Consumption">True for consumption undo.</param>
    /// <param name="Request">The request.</param>
    /// <param name="LanguageId">The call language.</param>
    /// <returns>The answer.</returns>
    procedure Send(Consumption: Boolean; Request: JsonObject; LanguageId: Integer): JsonObject
    begin
        if Consumption then
            exit(Data.Invoke("Message Type ori"::"Service.Consumption.Undo", Request, '', LanguageId, false));
        exit(Data.Invoke("Message Type ori"::"Service.Shipment.Undo", Request, '', LanguageId, false));
    end;

    /// <summary>Undoes one line with expectedCount 1.</summary>
    /// <param name="Consumption">True for consumption undo.</param>
    /// <param name="ShipmentNo">The posted shipment.</param>
    /// <param name="LineNo">The line.</param>
    /// <returns>The answer.</returns>
    procedure UndoLine(Consumption: Boolean; ShipmentNo: Code[20]; LineNo: Integer): JsonObject
    var
        LineNos: List of [Integer];
    begin
        LineNos.Add(LineNo);
        exit(Send(Consumption, Build(ShipmentNo, LineNos, 1), 1033));
    end;

    /// <summary>Counts the correction lines on a posted shipment.</summary>
    /// <param name="ShipmentNo">The posted shipment.</param>
    /// <returns>The number of lines with Correction = true and negative quantity.</returns>
    procedure CorrectionLines(ShipmentNo: Code[20]): Integer
    var
        ShipmentLine: Record "Service Shipment Line";
    begin
        ShipmentLine.SetRange("Document No.", ShipmentNo);
        ShipmentLine.SetRange(Correction, true);
        ShipmentLine.SetFilter(Quantity, '<0');
        exit(ShipmentLine.Count());
    end;

    /// <summary>Asserts a refusal code and that no correction line was posted.</summary>
    /// <param name="Response">The answer.</param>
    /// <param name="Code">The expected code.</param>
    /// <param name="ShipmentNo">The posted shipment.</param>
    procedure AssertRefusedNothingPosted(Response: JsonObject; Code: Text; ShipmentNo: Code[20])
    var
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.AreEqual(Code, Data.TextValue(Response, 'code'), Serialized);
        Data.AssertRefusal(Response, Code);
        Assert.AreEqual(0, CorrectionLines(ShipmentNo), 'Nothing is posted: ' + Serialized);
    end;
}
