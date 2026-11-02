namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using System.TestLibraries.Utilities;
using System.TestTools.TestRunner;

/// <summary>Checks the shared service fixture independently of lifecycle policy choices; these are not message acceptance tests.</summary>
codeunit 97711 "Svc Fixture Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "Svc Test Data ori";

    [Test]
    procedure Suite_SelectsRegistrationAndFixtureTests()
    var
        TestLine: Record "Test Method Line";
    begin
        TestLine.SetLoadFields("Test Suite", "Test Codeunit", "Line Type");
        TestLine.SetRange("Test Suite", 'SERVICEMGT');
        TestLine.SetRange("Line Type", TestLine."Line Type"::Function);
        TestLine.SetRange("Test Codeunit", Codeunit::"Svc Registration Tst ori");
        Assert.AreEqual(2, TestLine.Count(), 'Installed suite must select both registration tests.');
        TestLine.SetRange("Test Codeunit", Codeunit::"Svc Fixture Tests ori");
        Assert.AreEqual(4, TestLine.Count(), 'Installed suite must include every fixture test, including this suite check.');
    end;

    [Test]
    procedure Fixture_OrderHasOwnItemAndResourceLines()
    var
        ServiceHeader: Record "Service Header";
    begin
        TestData.CreateDocument(ServiceHeader, ServiceHeader."Document Type"::Order);
        AssertDocument(ServiceHeader);
    end;

    [Test]
    procedure Fixture_QuoteHasOwnItemAndResourceLines()
    var
        ServiceHeader: Record "Service Header";
    begin
        TestData.CreateDocument(ServiceHeader, ServiceHeader."Document Type"::Quote);
        AssertDocument(ServiceHeader);
    end;

    [Test]
    procedure Fixture_SetupQuoteCleanup_RequiresMarker()
    var
        Header: Record "Service Header";
        Number: Code[20];
    begin
        TestData.CreateHeader(Header, Header."Document Type"::Quote);
        Number := Header."No.";
        asserterror TestData.DeleteMcpSetupQuote(Number);
        Assert.ExpectedError('Description');
        Header.Get(Header."Document Type"::Quote, Number);
        Header.Description := 'Owned temporary generic-PK validation context';
        Header.Modify(true);
        TestData.DeleteMcpSetupQuote(Number);
        Assert.IsFalse(Header.Get(Header."Document Type"::Quote, Number), 'The marked empty setup quote must be removed.');
    end;

    local procedure AssertDocument(ServiceHeader: Record "Service Header")
    var
        ServiceLine: Record "Service Line";
        ServiceItemLine: Record "Service Item Line";
    begin
        Assert.AreEqual('X', CopyStr(ServiceHeader."No.", 1, 1), 'The fixture must own its document number.');
        Assert.AreEqual('X', CopyStr(ServiceHeader."Customer No.", 1, 1), 'The fixture must create its own customer.');
        Assert.AreEqual(ServiceHeader."Release Status"::Open, ServiceHeader."Release Status", 'New fixture must be open.');
        ServiceItemLine.SetLoadFields("Document Type", "Document No.", "Service Item No.");
        ServiceItemLine.SetRange("Document Type", ServiceHeader."Document Type");
        ServiceItemLine.SetRange("Document No.", ServiceHeader."No.");
        Assert.AreEqual(1, ServiceItemLine.Count(), 'Fixture requires one service item line.');
        ServiceItemLine.FindFirst();
        Assert.AreEqual('X', CopyStr(ServiceItemLine."Service Item No.", 1, 1), 'Service item must be newly created.');
        ServiceLine.SetLoadFields("Document Type", "Document No.", Type, Quantity, "No.");
        ServiceLine.SetRange("Document Type", ServiceHeader."Document Type");
        ServiceLine.SetRange("Document No.", ServiceHeader."No.");
        Assert.AreEqual(2, ServiceLine.Count(), 'Fixture requires exactly an item and resource line.');
        ServiceLine.SetRange(Type, ServiceLine.Type::Item);
        ServiceLine.FindFirst();
        Assert.AreEqual(2, ServiceLine.Quantity, 'Item quantity.');
        Assert.AreEqual('X', CopyStr(ServiceLine."No.", 1, 1), 'Own item.');
        ServiceLine.SetRange(Type, ServiceLine.Type::Resource);
        ServiceLine.FindFirst();
        Assert.AreEqual(3, ServiceLine.Quantity, 'Resource quantity.');
        Assert.AreEqual('X', CopyStr(ServiceLine."No.", 1, 1), 'Own resource.');
    end;
}
