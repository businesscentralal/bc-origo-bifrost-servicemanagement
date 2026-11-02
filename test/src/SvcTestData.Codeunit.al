namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Setup;
using Microsoft.Service.Test;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Creates isolated service lifecycle fixtures and invokes Foundation's public dispatcher.</summary>
codeunit 97704 "Svc Test Data ori"
{
    var
        Assert: Codeunit "Library Assert";

    /// <summary>Configures fresh service number series inside the caller's test transaction, without changing licence or consent state.</summary>
    procedure SetupNumbering()
    var
        Setup: Record "Service Mgt. Setup";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        Utility: Codeunit "Library - Utility";
    begin
        Utility.CreateNoSeries(Series, true, true, false);
        Series.Rename(NewCode());
        Utility.CreateNoSeriesLine(SeriesLine, Series.Code, CopyStr(Series.Code, 1, 12) + '000001', CopyStr(Series.Code, 1, 12) + '999999');
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup.Validate("Service Order Nos.", Series.Code);
        Setup.Validate("Service Quote Nos.", Series.Code);
        Setup.Validate("Service Invoice Nos.", Series.Code);
        Setup.Validate("Service Credit Memo Nos.", Series.Code);
        Setup.Validate("Service Item Nos.", Series.Code);
        Setup.Modify(true);
    end;

    /// <summary>Creates a document with its own customer, service item, service item line, item line and resource line.</summary>
    procedure CreateDocument(var ServiceHeader: Record "Service Header"; DocumentType: Enum "Service Document Type")
    var
        Customer: Record Customer;
        Item: Record Item;
        Resource: Record Resource;
        ServiceItem: Record "Service Item";
        ServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        Sales: Codeunit "Library - Sales";
        Inventory: Codeunit "Library - Inventory";
        Resources: Codeunit "Library - Resource";
        Service: Codeunit "Library - Service";
    begin
        SetupNumbering();
        Sales.CreateCustomer(Customer);
        Customer.Rename(NewCode());
        Service.CreateServiceHeader(ServiceHeader, DocumentType, Customer."No.");
        Service.CreateServiceItem(ServiceItem, Customer."No.");
        Service.CreateServiceItemLine(ServiceItemLine, ServiceHeader, ServiceItem."No.");
        Inventory.CreateItem(Item);
        Item.Rename(NewCode());
        Service.CreateServiceLineWithQuantity(ServiceLine, ServiceHeader, ServiceLine.Type::Item, Item."No.", 2);
        ServiceLine.Validate("Service Item Line No.", ServiceItemLine."Line No.");
        ServiceLine.Validate("Unit Price", 10);
        ServiceLine.Modify(true);
        Resources.CreateResource(Resource, Customer."VAT Bus. Posting Group");
        Resource.Rename(NewCode());
        Service.CreateServiceLineWithQuantity(ServiceLine, ServiceHeader, ServiceLine.Type::Resource, Resource."No.", 3);
        ServiceLine.Validate("Service Item Line No.", ServiceItemLine."Line No.");
        ServiceLine.Validate("Unit Price", 10);
        ServiceLine.Modify(true);
    end;

    /// <summary>Creates only the header needed for wrong-document-type rejection, without unsupported credit-memo service item lines.</summary>
    procedure CreateHeader(var Header: Record "Service Header"; DocumentType: Enum "Service Document Type")
    var
        Customer: Record Customer;
        Sales: Codeunit "Library - Sales";
        Service: Codeunit "Library - Service";
    begin
        SetupNumbering();
        Sales.CreateCustomer(Customer);
        Customer.Rename(NewCode());
        Service.CreateServiceHeader(Header, DocumentType, Customer."No.");
    end;

    /// <summary>Invokes a message through the public dispatcher with explicit language, subject and transaction mode.</summary>
    procedure Invoke(MessageType: Enum "Message Type ori"; Request: JsonObject; Subject: Text; LanguageId: Integer; OmitCommit: Boolean): JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        PreviousLanguage: Integer;
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        Response: JsonObject;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.WriteTo(RequestText);
        Input.AddText(RequestText);
        if OmitCommit then
            Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250), '', 'text/json', Input, Output, ContentType, true)
        else
            Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250), '', 'text/json', Input, TaskId, LanguageId, MessageId, Output, ContentType, ResponseTime);
        GlobalLanguage(PreviousLanguage);
        Output.GetSubText(ResponseText, 1);
        if not Response.ReadFrom(ResponseText) then
            Error('Dispatcher must return JSON.');
        exit(Response);
    end;

    /// <summary>Reads a required JSON string for assertions.</summary>
    procedure TextValue(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Asserts a structured refusal and useful recovery guidance.</summary>
    procedure AssertRefusal(Response: JsonObject; Code: Text)
    begin
        Assert.AreEqual('Error', TextValue(Response, 'status'), 'Expected a refusal.');
        Assert.AreEqual(Code, TextValue(Response, 'code'), 'Unexpected error code.');
        Assert.AreNotEqual('', TextValue(Response, 'error'), 'Refusal must explain the problem.');
        if Code <> 'MultipleErrors' then
            Assert.AreNotEqual('', TextValue(Response, 'nextStep'), 'Refusal must offer recovery guidance.');
    end;
    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-{}'), 1, 20));
    end;

}
