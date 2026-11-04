namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Setup;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Creates postable service order fixtures and reads posting answers for the posting tests.</summary>
codeunit 97749 "Svc Post Data ori"
{
    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Creates an order with an item line (quantity 2) and a resource line (quantity 3), all quantities to post, with inventory allowed to go negative.</summary>
    procedure CreateOrder(var Header: Record "Service Header")
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.Get();
        if InventorySetup."Prevent Negative Inventory" then begin
            InventorySetup."Prevent Negative Inventory" := false;
            InventorySetup.Modify();
        end;
        Data.CreateDocument(Header, Header."Document Type"::Order);
    end;

    /// <summary>Sends a Service.Order.Post request with the given flags (a flag is sent only when its text is not empty).</summary>
    procedure Post(OrderNo: Code[20]; Ship: Text; Consume: Text; Invoice: Text; Count: Integer; LanguageId: Integer): JsonObject
    begin
        exit(Data.Invoke("Message Type ori"::"Service.Order.Post", Build(OrderNo, Ship, Consume, Invoice, Count), '', LanguageId, false));
    end;

    /// <summary>Sends a Service.Order.PreviewPost request with the given flags.</summary>
    procedure Preview(OrderNo: Code[20]; Ship: Text; Consume: Text; Invoice: Text; LanguageId: Integer): JsonObject
    begin
        exit(Data.Invoke("Message Type ori"::"Service.Order.PreviewPost", Build(OrderNo, Ship, Consume, Invoice, 0), '', LanguageId, false));
    end;

    /// <summary>Builds a request; flag text must be true or false, or empty to omit the key. A count of 0 omits expectedCount.</summary>
    procedure Build(OrderNo: Code[20]; Ship: Text; Consume: Text; Invoice: Text; Count: Integer) Request: JsonObject
    begin
        Request.Add('no', OrderNo);
        AddFlag(Request, 'ship', Ship);
        AddFlag(Request, 'consume', Consume);
        AddFlag(Request, 'invoice', Invoice);
        if Count > 0 then
            Request.Add('expectedCount', Count);
    end;

    /// <summary>Sets Qty. to Ship, Qty. to Consume and Qty. to Invoice on every line to the same fraction of its quantity.</summary>
    procedure SetQuantities(Header: Record "Service Header"; ToShip: Decimal; ToConsume: Decimal; ToInvoice: Decimal)
    var
        Line: Record "Service Line";
    begin
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.FindSet(true);
        repeat
            Line.Validate("Qty. to Ship", ToShip);
            Line.Validate("Qty. to Consume", ToConsume);
            Line.Validate("Qty. to Invoice", ToInvoice);
            Line.Modify(true);
        until Line.Next() = 0;
        Commit();
    end;

    /// <summary>Counts the posted documents of the order.</summary>
    procedure PostedShipments(OrderNo: Code[20]): Integer
    var
        ShipmentHeader: Record "Service Shipment Header";
    begin
        ShipmentHeader.SetRange("Order No.", OrderNo);
        exit(ShipmentHeader.Count());
    end;

    /// <summary>Counts the posted invoices of the order.</summary>
    procedure PostedInvoices(OrderNo: Code[20]): Integer
    var
        InvoiceHeader: Record "Service Invoice Header";
    begin
        InvoiceHeader.SetRange("Order No.", OrderNo);
        exit(InvoiceHeader.Count());
    end;

    /// <summary>Returns a JSON array element count for a response key.</summary>
    procedure ArrayCount(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsArray().Count());
    end;

    /// <summary>Returns an integer response value.</summary>
    procedure IntegerValue(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Returns a boolean response value.</summary>
    procedure BooleanValue(Response: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>Asserts a successful answer and returns the serialized text for diagnostics.</summary>
    procedure AssertSuccess(Response: JsonObject)
    var
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Serialized);
    end;

    local procedure AddFlag(var Request: JsonObject; KeyName: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        Request.Add(KeyName, Value = 'true');
    end;
}
