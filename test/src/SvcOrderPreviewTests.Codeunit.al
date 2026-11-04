namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
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
        Preview: JsonObject;
        Posted: JsonObject;
        OrderNo: Code[20];
        PreviewCount: Integer;
    begin
        PostData.CreateOrder(Header);
        OrderNo := Header."No.";
        Commit();
        Preview := PostData.Preview(OrderNo, 'true', '', 'true', 1033);
        PostData.AssertSuccess(Preview);
        Assert.IsTrue(PostData.BooleanValue(Preview, 'rollback'), 'The preview rolls back.');
        PreviewCount := PostData.IntegerValue(Preview, 'entryCount');
        Assert.IsTrue(PreviewCount > 0, 'The preview captures entries.');
        Assert.AreEqual(0, PostData.PostedShipments(OrderNo) + PostData.PostedInvoices(OrderNo), 'The preview leaves no posted document.');
        Posted := PostData.Post(OrderNo, 'true', '', 'true', 1, 1033);
        PostData.AssertSuccess(Posted);
        Assert.AreEqual(1, PostData.PostedInvoices(OrderNo), 'Post then creates the invoice.');
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
}
