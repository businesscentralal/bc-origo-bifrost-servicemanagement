namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Ledger;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Item;
using Microsoft.Service.Ledger;
using System.TestLibraries.Utilities;

/// <summary>Proves Service.Shipment.Undo and Service.Consumption.Undo undo posted lines through the standard Business Central undo.</summary>
codeunit 97751 "Svc Undo Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        UndoData: Codeunit "Svc Undo Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_ShipmentUndo_ItemLine_RestoresOrderLine()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        ResourceShipment: Record "Service Shipment Line";
        OrderLine: Record "Service Line";
        ItemEntry: Record "Item Ledger Entry";
        Response: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        UndoData.FindLine(ShipmentNo, ResourceShipment.Type::Resource, ResourceShipment);
        Response := UndoData.UndoLine(false, ShipmentNo, ItemShipment."Line No.");
        PostData.AssertSuccess(Response);
        Assert.AreEqual(1, PostData.IntegerValue(Response, 'reversedCount'), 'One line is undone.');
        Assert.AreEqual(Header."No.", Data.TextValue(Response, 'serviceOrderNo'), 'The order is named.');
        Assert.AreEqual(1, UndoData.CorrectionLines(ShipmentNo), 'One correction line is inserted.');
        ItemShipment.Get(ItemShipment."Document No.", ItemShipment."Line No.");
        Assert.IsTrue(ItemShipment.Correction, 'The undone line is marked as corrected.');
        ItemEntry.SetRange("Item No.", ItemShipment."No.");
        ItemEntry.SetRange("Document No.", ShipmentNo);
        ItemEntry.CalcSums(Quantity);
        Assert.AreEqual(0, ItemEntry.Quantity, 'The item ledger entry is reversed.');
        Assert.AreEqual(2, ItemEntry.Count(), 'The original and the correcting item entry exist.');
        OrderLine.Get(OrderLine."Document Type"::Order, Header."No.", ItemShipment."Order Line No.");
        Assert.AreEqual(0, OrderLine."Quantity Shipped", 'Quantity Shipped returns to zero.');
        Assert.AreEqual(2, OrderLine."Qty. to Ship", 'Qty. to Ship is restored.');
        OrderLine.Get(OrderLine."Document Type"::Order, Header."No.", ResourceShipment."Order Line No.");
        Assert.AreEqual(3, OrderLine."Quantity Shipped", 'The resource line is untouched.');
        ResourceShipment.Get(ResourceShipment."Document No.", ResourceShipment."Line No.");
        Assert.IsFalse(ResourceShipment.Correction, 'The resource shipment line is untouched.');
    end;

    [Test]
    procedure Scenario_AC01_ShipmentUndo_AllLines_Icelandic()
    var
        Header: Record "Service Header";
        LineNos: List of [Integer];
        Response: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        Response := UndoData.Send(false, UndoData.Build(ShipmentNo, LineNos, 1), 1039);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(2, PostData.IntegerValue(Response, 'reversedCount'), 'Both lines are undone.');
        Assert.AreEqual(2, PostData.ArrayCount(Response, 'lines'), 'Both lines are listed.');
        Assert.AreEqual(2, UndoData.CorrectionLines(ShipmentNo), 'Two correction lines are inserted.');
    end;

    [Test]
    procedure Scenario_AC02_ConsumptionUndo_RestoresConsumption()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        ResourceShipment: Record "Service Shipment Line";
        OrderLine: Record "Service Line";
        ItemEntry: Record "Item Ledger Entry";
        ResEntry: Record "Res. Ledger Entry";
        ServiceEntry: Record "Service Ledger Entry";
        LineNos: List of [Integer];
        Response: JsonObject;
        ShipmentNo: Code[20];
        Serialized: Text;
    begin
        ShipmentNo := UndoData.ShipOrder(Header, true);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        UndoData.FindLine(ShipmentNo, ResourceShipment.Type::Resource, ResourceShipment);
        LineNos.Add(ItemShipment."Line No.");
        LineNos.Add(ResourceShipment."Line No.");
        Response := UndoData.Send(true, UndoData.Build(ShipmentNo, LineNos, 1), 1033);
        Response.WriteTo(Serialized);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(2, PostData.IntegerValue(Response, 'reversedCount'), Serialized);
        OrderLine.Get(OrderLine."Document Type"::Order, Header."No.", ItemShipment."Order Line No.");
        Assert.AreEqual(0, OrderLine."Quantity Consumed", 'Item consumption is undone.');
        Assert.AreEqual(0, OrderLine."Quantity Shipped", 'The consumed shipment is reversed.');
        OrderLine.Get(OrderLine."Document Type"::Order, Header."No.", ResourceShipment."Order Line No.");
        Assert.AreEqual(0, OrderLine."Quantity Consumed", 'Resource consumption is undone.');
        ItemEntry.SetRange("Item No.", ItemShipment."No.");
        ItemEntry.SetRange("Document No.", ShipmentNo);
        ItemEntry.CalcSums(Quantity);
        Assert.AreEqual(0, ItemEntry.Quantity, 'The item entries are reversed.');
        ResEntry.SetRange("Resource No.", ResourceShipment."No.");
        ResEntry.SetRange("Document No.", ShipmentNo);
        ResEntry.CalcSums(Quantity);
        Assert.AreEqual(0, ResEntry.Quantity, 'The resource entries are reversed.');
        ServiceEntry.SetRange("Service Order No.", Header."No.");
        ServiceEntry.SetRange("Document No.", ShipmentNo);
        ServiceEntry.SetRange("Entry Type", ServiceEntry."Entry Type"::Consume);
        ServiceEntry.CalcSums(Quantity);
        Assert.AreEqual(0, ServiceEntry.Quantity, 'The consumption service ledger entries are reversed.');
    end;

    [Test]
    procedure Scenario_AC02_ShipmentUndo_ConsumedLine_PreconditionFailed()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, true);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        UndoData.AssertRefusedNothingPosted(UndoData.UndoLine(false, ShipmentNo, ItemShipment."Line No."), 'PreconditionFailed', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC02_ConsumptionUndo_NotConsumed_PreconditionFailed()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        UndoData.AssertRefusedNothingPosted(UndoData.UndoLine(true, ShipmentNo, ItemShipment."Line No."), 'PreconditionFailed', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC03_NoCount_ConfirmationRequired_ListsLines()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        LineNos: List of [Integer];
        Response: JsonObject;
        Serialized: Text;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        LineNos.Add(ItemShipment."Line No.");
        Response := UndoData.Send(false, UndoData.Build(ShipmentNo, LineNos, 0), 1033);
        Response.WriteTo(Serialized);
        UndoData.AssertRefusedNothingPosted(Response, 'ConfirmationRequired', ShipmentNo);
        Assert.IsTrue(Serialized.Contains(Format(ItemShipment."Line No.", 0, 9)), 'The line list is returned: ' + Serialized);
        Assert.IsTrue(Serialized.Contains(ShipmentNo), 'The shipment is named: ' + Serialized);
    end;

    [Test]
    procedure Scenario_AC03_WrongCount_ConfirmationMismatch()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        LineNos: List of [Integer];
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        LineNos.Add(ItemShipment."Line No.");
        UndoData.AssertRefusedNothingPosted(UndoData.Send(false, UndoData.Build(ShipmentNo, LineNos, 2), 1033), 'ConfirmationMismatch', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC04_InvoicedLine_PreconditionFailed()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        Response: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        // The state Business Central leaves on a shipment line after its quantity is invoiced.
        ItemShipment."Quantity Invoiced" := ItemShipment.Quantity;
        ItemShipment."Qty. Invoiced (Base)" := ItemShipment."Quantity (Base)";
        ItemShipment."Qty. Shipped Not Invoiced" := 0;
        ItemShipment."Qty. Shipped Not Invd. (Base)" := 0;
        ItemShipment.Modify();
        Commit();
        Response := UndoData.UndoLine(false, ShipmentNo, ItemShipment."Line No.");
        UndoData.AssertRefusedNothingPosted(Response, 'PreconditionFailed', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC04_UnknownShipment_RecordNotFound()
    var
        Response: JsonObject;
    begin
        Response := UndoData.UndoLine(false, 'NOSUCHSHIPMENT', 10000);
        Data.AssertRefusal(Response, 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC04_LineOfOtherShipment_RecordNotFound()
    var
        Header: Record "Service Header";
        Other: Record "Service Header";
        OtherLine: Record "Service Shipment Line";
        LastLine: Record "Service Shipment Line";
        ShipmentNo: Code[20];
        OtherNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        OtherNo := UndoData.ShipOrder(Other, false);
        LastLine.SetRange("Document No.", ShipmentNo);
        LastLine.FindLast();
        OtherLine.SetRange("Document No.", OtherNo);
        OtherLine.FindLast();
        UndoData.AssertRefusedNothingPosted(UndoData.UndoLine(false, ShipmentNo, LastLine."Line No." + OtherLine."Line No." + 1), 'RecordNotFound', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC04_DifferentIdentifiers_Conflicting()
    var
        Header: Record "Service Header";
        Other: Record "Service Header";
        OtherHeader: Record "Service Shipment Header";
        LineNos: List of [Integer];
        Request: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        OtherHeader.Get(UndoData.ShipOrder(Other, false));
        Request := UndoData.Build(ShipmentNo, LineNos, 1);
        Request.Add('systemId', Format(OtherHeader.SystemId, 0, 4));
        UndoData.AssertRefusedNothingPosted(UndoData.Send(false, Request, 1033), 'ConflictingIdentifiers', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC04_TextInLineNos_InvalidParameterFormat()
    var
        Header: Record "Service Header";
        LineNos: List of [Integer];
        Numbers: JsonArray;
        Request: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        Request := UndoData.Build(ShipmentNo, LineNos, 1);
        Numbers.Add('10000');
        Request.Add('lineNos', Numbers);
        UndoData.AssertRefusedNothingPosted(UndoData.Send(false, Request, 1033), 'InvalidParameterFormat', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC04_CorrectionLine_InvalidParameterFormat()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        Response: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        PostData.AssertSuccess(UndoData.UndoLine(false, ShipmentNo, ItemShipment."Line No."));
        Response := UndoData.UndoLine(false, ShipmentNo, ItemShipment."Line No.");
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Assert.AreEqual(1, UndoData.CorrectionLines(ShipmentNo), 'Nothing more is posted.');
    end;

    [Test]
    procedure Scenario_AC04_UnknownKey_UnknownParameter()
    var
        Header: Record "Service Header";
        LineNos: List of [Integer];
        Request: JsonObject;
        ShipmentNo: Code[20];
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        Request := UndoData.Build(ShipmentNo, LineNos, 1);
        Request.Add('quantity', 1);
        UndoData.AssertRefusedNothingPosted(UndoData.Send(false, Request, 1033), 'UnknownParameter', ShipmentNo);
    end;

    [Test]
    procedure Scenario_AC05_CreatedServiceItem_Refused_ItemKept()
    var
        Header: Record "Service Header";
        ItemShipment: Record "Service Shipment Line";
        ServiceItem: Record "Service Item";
        Response: JsonObject;
        ShipmentNo: Code[20];
        Serialized: Text;
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, ItemShipment.Type::Item, ItemShipment);
        // The state Business Central leaves when a shipment line creates a service item.
        ServiceItem.Init();
        ServiceItem."No." := CopyStr('UNDO' + ShipmentNo, 1, MaxStrLen(ServiceItem."No."));
        ServiceItem."Customer No." := Header."Customer No.";
        ServiceItem."Sales/Serv. Shpt. Document No." := ShipmentNo;
        ServiceItem."Sales/Serv. Shpt. Line No." := ItemShipment."Line No.";
        ServiceItem."Shipment Type" := ServiceItem."Shipment Type"::Service;
        ServiceItem.Insert();
        Commit();
        Response := UndoData.UndoLine(false, ShipmentNo, ItemShipment."Line No.");
        Response.WriteTo(Serialized);
        UndoData.AssertRefusedNothingPosted(Response, 'PreconditionFailed', ShipmentNo);
        Assert.IsTrue(ServiceItem.Get(ServiceItem."No."), 'The service item still exists.');
        Assert.IsTrue(Serialized.Contains('service item'), 'The refusal names the service items: ' + Serialized);
    end;
}
