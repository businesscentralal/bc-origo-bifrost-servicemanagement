namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Service.Document;
using Microsoft.Service.Setup;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves Service.Order.PreviewPost shows the entries Post would create and changes nothing.</summary>
codeunit 97741 "Svc Order Preview Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC11_Preview_MatchesPost_AndChangesNothing()
    var
        Header: Record "Service Header";
        Setup: Record "Service Mgt. Setup";
        NoSeries: Codeunit "No. Series";
        Counts: Dictionary of [Integer, Integer];
        Preview: JsonObject;
        Posted: JsonObject;
        OrderNo: Code[20];
        PreviewCount: Integer;
        ShipmentNextNo: Code[20];
        InvoiceNextNo: Code[20];
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        Setup.Get();
        ShipmentNextNo := NoSeries.PeekNextNo(Setup."Posted Service Shipment Nos.", Header."Posting Date");
        InvoiceNextNo := NoSeries.PeekNextNo(Setup."Posted Service Invoice Nos.", Header."Posting Date");
        Preview := PostData.Preview(OrderNo, 'true', '', 'true', 1033);
        PostData.AssertSuccess(Preview);
        Assert.IsTrue(PostData.BooleanValue(Preview, 'rollback'), 'The preview rolls back.');
        PreviewCount := PostData.IntegerValue(Preview, 'entryCount');
        Assert.IsTrue(PreviewCount > 0, 'The preview captures entries.');
        Assert.AreEqual(0, PostData.PostedShipments(OrderNo) + PostData.PostedInvoices(OrderNo), 'The preview leaves no posted document.');
        Assert.AreEqual(ShipmentNextNo, NoSeries.PeekNextNo(Setup."Posted Service Shipment Nos.", Header."Posting Date"), 'Preview consumes no shipment number.');
        Assert.AreEqual(InvoiceNextNo, NoSeries.PeekNextNo(Setup."Posted Service Invoice Nos.", Header."Posting Date"), 'Preview consumes no invoice number.');
        CaptureTableCounts(Preview, Counts);
        Posted := PostData.Post(OrderNo, 'true', '', 'true', 1, 1033);
        PostData.AssertSuccess(Posted);
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'Post then creates the invoice.');
        ComparePostedCounts(Preview, Counts);
    end;

    [Test]
    procedure Scenario_AC11_OmitCommit_PreconditionFailed()
    var
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.PreviewPost", PostData.Build(Header."No.", 'true', '', 'true', 0), '', 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC18_Icelandic_PreviewSummary()
    var
        Header: Record "Service Header";
        Response: JsonObject;
        Serialized: Text;
    begin
        PostData.CreateOrder(Header);
        Commit();
        Response := PostData.Preview(Header."No.", 'true', '', 'true', 1039);
        PostData.AssertSuccess(Response);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('Forskoðun'), 'The summary is Icelandic at 1039.');
    end;
    local procedure CaptureTableCounts(Preview: JsonObject; var Counts: Dictionary of [Integer, Integer])
    var
        TableRef: RecordRef;
        TablesToken: JsonToken;
        TableToken: JsonToken;
        TableIdToken: JsonToken;
        TableId: Integer;
    begin
        Preview.Get('preview', TablesToken);
        foreach TableToken in TablesToken.AsArray() do begin
            TableToken.AsObject().Get('tableId', TableIdToken);
            TableId := TableIdToken.AsValue().AsInteger();
            TableRef.Open(TableId);
            Counts.Add(TableId, TableRef.Count());
            TableRef.Close();
        end;
    end;

    local procedure ComparePostedCounts(Preview: JsonObject; Counts: Dictionary of [Integer, Integer])
    var
        TableRef: RecordRef;
        TablesToken: JsonToken;
        TableToken: JsonToken;
        ValueToken: JsonToken;
        TableId: Integer;
        ActualCount: Integer;
        Total: Integer;
    begin
        Preview.Get('preview', TablesToken);
        foreach TableToken in TablesToken.AsArray() do begin
            TableToken.AsObject().Get('tableId', ValueToken);
            TableId := ValueToken.AsValue().AsInteger();
            TableRef.Open(TableId);
            ActualCount := TableRef.Count() - Counts.Get(TableId);
            TableRef.Close();
            TableToken.AsObject().Get('entryCount', ValueToken);
            Assert.AreEqual(ValueToken.AsValue().AsInteger(), ActualCount, 'Preview and native posting entry counts must agree for table ' + Format(TableId));
            Total += ActualCount;
        end;
        Assert.AreEqual(PostData.IntegerValue(Preview, 'entryCount'), Total, 'The preview total equals the entries actually posted.');
    end;

}
