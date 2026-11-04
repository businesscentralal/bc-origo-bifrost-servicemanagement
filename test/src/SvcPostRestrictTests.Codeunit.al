namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves posted quantities are written only by posting while the quantities to post stay writable.</summary>
codeunit 97744 "Svc Post Restrict Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC14_PostedQuantity_IsRefused_WithHint()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Response: JsonObject;
        Serialized: Text;
    begin
        PostData.CreateOrder(Header);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.FindFirst();
        Commit();
        Response := SetField(Header."No.", Line."Line No.", 'Quantity Shipped', '1');
        Data.AssertRefusal(Response, 'PermissionDenied');
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('Service.Order.Post'), 'The refusal names the dedicated type.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(0, Line."Quantity Shipped", 'The field is unchanged.');
    end;

    [Test]
    procedure Scenario_AC14_QtyToShip_StaysWritable()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Response: JsonObject;
        Serialized: Text;
    begin
        PostData.CreateOrder(Header);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.FindFirst();
        Commit();
        Response := SetField(Header."No.", Line."Line No.", 'Qty. to Ship', '1');
        Response.WriteTo(Serialized);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Serialized);
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(1, Line."Qty. to Ship", 'Qty. to Ship is written.');
    end;

    local procedure SetField(OrderNo: Code[20]; LineNo: Integer; FieldName: Text; Value: Text): JsonObject
    var
        Line: Record "Service Line";
        Request: JsonObject;
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
    begin
        Line.Get(Line."Document Type"::Order, OrderNo, LineNo);
        Fields.Add(FieldName, Value);
        Entry.Add('id', Format(Line.SystemId, 0, 4));
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Request.Add('tableName', 'Service Line');
        Request.Add('data', Entries);
        exit(Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', 1033, false));
    end;
}
