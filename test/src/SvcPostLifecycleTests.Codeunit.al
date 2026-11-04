namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Setup;
using Microsoft.Service.Document;
using Microsoft.Service.Maintenance;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Runs the complete service lifecycle through the public dispatcher on self-created data.</summary>
codeunit 97746 "Svc Post Lifecycle Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC15_QuoteToConsumedAndInvoiced_English()
    begin
        // Story #7 AC15 | Time: WorkDate for BC posting; no wall-clock assumption | Risk: shared lifecycle types.
        RunLifecycle(1033);
    end;

    [Test]
    procedure Scenario_AC15_QuoteToConsumedAndInvoiced_Icelandic()
    begin
        // Story #7 AC15 | Time: WorkDate for BC posting; no wall-clock assumption | Risk: shared lifecycle types.
        RunLifecycle(1039);
    end;

    local procedure RunLifecycle(LanguageId: Integer)
    var
        FixtureHeader: Record "Service Header";
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Line: Record "Service Line";
        InventorySetup: Record "Inventory Setup";
        RepairStatus: Record "Repair Status";
        Request: JsonObject;
        Fields: JsonObject;
        PrimaryKey: JsonObject;
        Response: JsonObject;
        QuoteNo: Code[20];
        OrderNo: Code[20];
        ResourceNo: Code[20];
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
    begin
        // [GIVEN] Native libraries create only isolated master data and a template; the workflow quote is created via Data.Records.Set.
        Data.CreateDocument(FixtureHeader, FixtureHeader."Document Type"::Quote);
        Data.ConfigureMcpWriteLogging();
        Data.SilenceServiceRules(Zones, Skills);
        InventorySetup.Get();
        InventorySetup."Prevent Negative Inventory" := false;
        InventorySetup.Modify();
        RepairStatus.Init();
        RepairStatus.Code := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(RepairStatus.Code));
        RepairStatus."Posting Allowed" := true;
        RepairStatus.Insert(true);
        QuoteNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(QuoteNo));
        PrimaryKey.Add('DocumentType', 'Quote');
        PrimaryKey.Add('No_', QuoteNo);
        Fields.Add('CustomerNo_', FixtureHeader."Customer No.");
        Commit();
        SetRecord('Service Header', PrimaryKey, Fields, LanguageId);
        Header.Get(Header."Document Type"::Quote, QuoteNo);
        ItemLine.SetRange("Document Type", FixtureHeader."Document Type");
        ItemLine.SetRange("Document No.", FixtureHeader."No.");
        ItemLine.FindFirst();
        Clear(PrimaryKey);
        Clear(Fields);
        PrimaryKey.Add('DocumentType', 'Quote');
        PrimaryKey.Add('DocumentNo_', QuoteNo);
        PrimaryKey.Add('LineNo_', 10000);
        Fields.Add('ServiceItemNo_', ItemLine."Service Item No.");
        SetRecord('Service Item Line', PrimaryKey, Fields, LanguageId);
        Line.SetRange("Document Type", FixtureHeader."Document Type");
        Line.SetRange("Document No.", FixtureHeader."No.");
        Line.FindSet();
        repeat
            Clear(PrimaryKey);
            Clear(Fields);
            PrimaryKey.Add('DocumentType', 'Quote');
            PrimaryKey.Add('DocumentNo_', QuoteNo);
            PrimaryKey.Add('LineNo_', Line."Line No.");
            if Line.Type = Line.Type::Item then
                Fields.Add('Type', 'Item')
            else begin
                Fields.Add('Type', 'Resource');
                ResourceNo := Line."No.";
            end;
            Fields.Add('No_', Line."No.");
            Fields.Add('ServiceItemLineNo_', 10000);
            Fields.Add('Quantity', Line.Quantity);
            Fields.Add('UnitPrice', 10);
            SetRecord('Service Line', PrimaryKey, Fields, LanguageId);
        until Line.Next() = 0;
        // [WHEN] Convert, allocate, release, set quantities, preview, consume one unit and invoice the remainder.
        Request.Add('no', QuoteNo);
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Quote.MakeOrder", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
        OrderNo := CopyStr(Data.TextValue(Response, 'orderNo'), 1, MaxStrLen(OrderNo));
        Clear(Request);
        Request.Add('documentNo', OrderNo);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('allocatedHours', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
        Clear(Request);
        Request.Add('no', OrderNo);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
        // The posting-allowed status preserves the order's current native status; unrelated transition policy remains intact.
        Header.Get(Header."Document Type"::Order, OrderNo);
        RepairStatus.Validate("Service Order Status", Header.Status);
        RepairStatus.Modify(true);
        Commit();
        Clear(PrimaryKey);
        Clear(Fields);
        PrimaryKey.Add('DocumentType', 'Order');
        PrimaryKey.Add('DocumentNo_', OrderNo);
        PrimaryKey.Add('LineNo_', 10000);
        Fields.Add('RepairStatusCode', RepairStatus.Code);
        SetRecord('Service Item Line', PrimaryKey, Fields, LanguageId);
        SetPostingQuantities(OrderNo, true, LanguageId);
        Response := PostData.Preview(OrderNo, 'true', 'true', '', LanguageId);
        PostData.AssertSuccess(Response);
        Assert.IsTrue(PostData.BooleanValue(Response, 'rollback'), 'Preview changes nothing.');
        Assert.AreEqual(0, PostData.PostedShipments(OrderNo), 'Preview creates no shipment.');
        Response := PostData.Post(OrderNo, 'true', 'true', '', 1, LanguageId);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(0, PostData.PostedInvoices(OrderNo), 'Consumption creates no invoice.');
        SetPostingQuantities(OrderNo, false, LanguageId);
        Response := PostData.Post(OrderNo, 'true', '', 'true', 1, LanguageId);
        Data.RestoreServiceRules(Zones, Skills);
        Commit();
        // [THEN] Both postings persist and native posting deletes the completed order.
        PostData.AssertSuccess(Response);
        Assert.AreEqual(2, PostData.PostedShipments(OrderNo), 'Two shipments cover consumption and invoice.');
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'One invoice covers the remaining quantities.');
        Assert.IsTrue(PostData.BooleanValue(Response, 'orderDeleted'), 'All quantities are consumed or invoiced.');
    end;

    local procedure SetPostingQuantities(OrderNo: Code[20]; Consume: Boolean; LanguageId: Integer)
    var
        Line: Record "Service Line";
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Line.SetRange("Document Type", Line."Document Type"::Order);
        Line.SetRange("Document No.", OrderNo);
        Line.FindSet();
        repeat
            Clear(Entry);
            Clear(Fields);
            Entry.Add('id', Format(Line.SystemId, 0, 4));
            if Consume then begin
                Fields.Add('Qty_toShip', 1);
                Fields.Add('Qty_toConsume', 1);
            end else begin
                Fields.Add('Qty_toShip', Line.Quantity - Line."Quantity Shipped");
                Fields.Add('Qty_toConsume', 0);
                Fields.Add('Qty_toInvoice', Line.Quantity - Line."Quantity Consumed" - Line."Quantity Invoiced");
            end;
            Entry.Add('fields', Fields);
            Entries.Add(Entry);
        until Line.Next() = 0;
        Request.Add('tableName', 'Service Line');
        Request.Add('data', Entries);
        Response := Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
    end;

    local procedure SetRecord(TableName: Text; PrimaryKey: JsonObject; Fields: JsonObject; LanguageId: Integer)
    var
        Entry: JsonObject;
        Entries: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Entry.Add('primaryKey', PrimaryKey);
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Request.Add('tableName', TableName);
        Request.Add('data', Entries);
        // Stable English enum tokens are accepted in either response language.
        Response := Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
    end;
}
