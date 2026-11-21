namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Ledger;
using Origo.Bifrost.ServiceManagement;
using Microsoft.Sales.Receivables;
using Microsoft.Service.Document;
using Microsoft.Service.History;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Exercises standalone billing through the public dispatcher on owned data.</summary>
codeunit 97757 "Svc Doc Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Doc Fixture ori";
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_TwoShipments_OnePostedInvoice_1033()
    begin
        // Story #22 AC01 | Time: WorkDate | Risk: native shipment and invoice posting.
        CombineAndPost(1033);
    end;

    [Test]
    procedure Scenario_AC01_TwoShipments_OnePostedInvoice_1039()
    begin
        // Story #22 AC01 | Time: WorkDate | Risk: native shipment and invoice posting.
        CombineAndPost(1039);
    end;

    local procedure CombineAndPost(LanguageId: Integer)
    var
        FirstOrder: Record "Service Header";
        SecondOrder: Record "Service Header";
        Invoice: Record "Service Header";
        Shipment: Record "Service Shipment Header";
        Line: Record "Service Line";
        Request: JsonObject;
        Response: JsonObject;
        Shipments: JsonArray;
        CustomerNo: Code[20];
        ResourceNo: Code[20];
    begin
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(FirstOrder, FirstOrder."Document Type"::Order, CustomerNo, ResourceNo);
        Fixture.Document(SecondOrder, SecondOrder."Document Type"::Order, CustomerNo, ResourceNo);
        Commit();
        PostData.AssertSuccess(PostData.Post(FirstOrder."No.", 'true', '', '', 1, LanguageId));
        PostData.AssertSuccess(PostData.Post(SecondOrder."No.", 'true', '', '', 1, LanguageId));
        Shipment.SetRange("Order No.", FirstOrder."No.");
        Shipment.FindFirst();
        Shipments.Add(Shipment."No.");
        Shipment.SetRange("Order No.", SecondOrder."No.");
        Shipment.FindFirst();
        Shipments.Add(Shipment."No.");
        Request.Add('customerNo', CustomerNo);
        Request.Add('shipmentNos', Shipments);
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
        Assert.IsTrue(PostData.BooleanValue(Response, 'created'), 'Creates an invoice.');
        Assert.IsTrue(PostData.IntegerValue(Response, 'linesAdded') >= 2, 'Adds both shipments.');
        Invoice.Get(Invoice."Document Type"::Invoice, Data.TextValue(Response, 'invoiceNo'));
        // Repeating collection on this invoice must not duplicate source lines.
        Request.Remove('customerNo');
        Request.Add('invoiceNo', Invoice."No.");
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', LanguageId, false);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(0, PostData.IntegerValue(Response, 'linesAdded'), 'Duplicate lines skipped.');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.PreviewPost", Fixture.Request(Invoice, 0), '', LanguageId, false);
        PostData.AssertSuccess(Response);
        Assert.IsTrue(PostData.IntegerValue(Response, 'entryCount') > 0, 'Invoice preview captures entries.');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Fixture.Request(Invoice, 1), '', LanguageId, false);
        PostData.AssertSuccess(Response);
        Assert.AreNotEqual('', Data.TextValue(Response, 'postedDocumentNo'), 'Posted identity returned.');
        Line.SetRange("Document Type", Line."Document Type"::Order);
        Line.SetFilter("Document No.", '%1|%2', FirstOrder."No.", SecondOrder."No.");
        Line.SetRange(Type, Line.Type::Resource);
        Assert.AreEqual(2, Line.Count(), 'Both source orders retained.');
        Line.FindSet();
        repeat
            Assert.AreEqual(Line.Quantity, Line."Quantity Invoiced", 'Source order fully invoiced.');
        until Line.Next() = 0;
        Assert.IsFalse(Invoice.Get(Invoice."Document Type", Invoice."No."), 'Native posting removes the invoice.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC02_CreditPreview_RollsBack_ThenPosts()
    var
        Header: Record "Service Header";
        Entry: Record "Cust. Ledger Entry";
        GL: Record "G/L Entry";
        Response: JsonObject;
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        BeforeGL: Integer;
    begin
        // Story #22 AC02 | Time: WorkDate | Risk: preview must leave no ledger entries.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::"Credit Memo", CustomerNo, ResourceNo);
        BeforeGL := GL.Count();
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.PreviewPost", Fixture.Request(Header, 0), '', 1033, false);
        PostData.AssertSuccess(Response);
        Assert.IsTrue(PostData.BooleanValue(Response, 'rollback'), 'Preview rolled back.');
        Assert.IsTrue(PostData.IntegerValue(Response, 'entryCount') > 0, 'Preview contains entries.');
        Assert.AreEqual(BeforeGL, GL.Count(), 'Preview left no G/L entries.');
        Entry.SetRange("Customer No.", CustomerNo);
        Assert.IsTrue(Entry.IsEmpty(), 'Preview left no customer entries.');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Fixture.Request(Header, 1), '', 1033, false);
        PostData.AssertSuccess(Response);
        Entry.SetRange("Document Type", Entry."Document Type"::"Credit Memo");
        Assert.IsTrue(Entry.FindFirst(), 'Customer credit exists.');
        Entry.CalcFields(Amount);
        Assert.IsTrue(Entry.Amount < 0, 'Credit reduces the customer balance.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC02_CreditPostsWithoutPreview()
    var
        Header: Record "Service Header";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
    begin
        // Story #22 AC02 | Time: WorkDate | Risk: standalone credit posting.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::"Credit Memo", CustomerNo, ResourceNo);
        Commit();
        PostData.AssertSuccess(InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Fixture.Request(Header, 1), '', 1033, false));
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC03_MissingAndWrongCount_NothingPosted()
    var
        Header: Record "Service Header";
        Credit: Record "Service Cr.Memo Header";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        Response: JsonObject;
    begin
        // Story #22 AC03 | Time: WorkDate | Risk: confirmation must precede posting.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::"Credit Memo", CustomerNo, ResourceNo);
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Fixture.Request(Header, 0), '', 1033, false);
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Fixture.Request(Header, 2), '', 1039, false);
        Data.AssertRefusal(Response, 'ConfirmationMismatch');
        Credit.SetRange("Pre-Assigned No.", Header."No.");
        Assert.IsTrue(Credit.IsEmpty(), 'No credit posted.');
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'Document retained.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_ContractErrors_AreStructured()
    var
        Request: JsonObject;
        Response: JsonObject;
        LanguageId: Integer;
        Pass: Integer;
    begin
        // Story #22 AC04 | Time: none | Risk: no writes on malformed requests.
        for Pass := 1 to 2 do begin
            LanguageId := 1033;
            if Pass = 2 then
                LanguageId := 1039;
            Clear(Request);
            Request.Add('no', 'OWN-NOT-FOUND');
            Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Request, '', LanguageId, false), 'MissingParameter');
            Request.Add('documentType', 'Order');
            Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Request, '', LanguageId, false);
            Data.AssertRefusal(Response, 'InvalidParameter');
            Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Service.Order.Post'), 'Orders use the existing path.');
            Request.Replace('documentType', 'Invoice');
            Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Request, '', LanguageId, false), 'RecordNotFound');
            Request.Add('unknown', true);
            Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Document.PreviewPost", Request, '', LanguageId, false), 'UnknownParameter');
            Clear(Request);
            Request.Add('customerNo', 'OWN-NOT-FOUND');
            Request.Add('shipmentNos', 'wrong');
            Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', LanguageId, false), 'InvalidParameterFormat');
            Request.Add('unknown', true);
            Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', LanguageId, false), 'UnknownParameter');
        end;
    end;

    [Test]
    procedure Scenario_AC04_OtherCustomer_NoInvoiceCreated()
    var
        Header: Record "Service Header";
        Invoice: Record "Service Header";
        Shipment: Record "Service Shipment Header";
        CustomerNo: Code[20];
        OtherCustomer: Code[20];
        ResourceNo: Code[20];
        Request: JsonObject;
        Shipments: JsonArray;
    begin
        // Story #22 AC04 | Time: WorkDate | Risk: validation must precede invoice creation.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::Order, CustomerNo, ResourceNo);
        Fixture.Create(OtherCustomer, ResourceNo);
        Commit();
        PostData.AssertSuccess(PostData.Post(Header."No.", 'true', '', '', 1, 1033));
        Shipment.SetRange("Order No.", Header."No.");
        Shipment.FindFirst();
        Shipments.Add(Shipment."No.");
        Request.Add('customerNo', OtherCustomer);
        Request.Add('shipmentNos', Shipments);
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1033, false), 'ConflictingIdentifiers');
        Invoice.SetRange("Document Type", Invoice."Document Type"::Invoice);
        Invoice.SetRange("Customer No.", OtherCustomer);
        Assert.IsTrue(Invoice.IsEmpty(), 'Refusal did not create an invoice.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_InvoiceSystemIdAndSubject_Agree()
    var
        Header: Record "Service Header";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #22 AC04 | Time: WorkDate | Risk: alternate identifiers must agree.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::Invoice, CustomerNo, ResourceNo);
        Request.Add('documentType', 'Invoice');
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Document.PreviewPost", Request, 'OTHER-DOCUMENT', 1033, false), 'ConflictingIdentifiers');
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Document.PreviewPost", Request, Header."No.", 1039, false);
        PostData.AssertSuccess(Response);
        Request.Add('expectedCount', 1);
        PostData.AssertSuccess(InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Request, Header."No.", 1039, false));
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_EmptyAllUninvoiced_AndBadArrays()
    var
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        Request: JsonObject;
        Response: JsonObject;
        Numbers: JsonArray;
        Token: JsonToken;
    begin
        // Story #22 AC04 | Time: WorkDate | Risk: empty selection and malformed arrays.
        Fixture.Create(CustomerNo, ResourceNo);
        Request.Add('customerNo', CustomerNo);
        Request.Add('allUninvoiced', true);
        Commit();
        Response := InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1039, false);
        PostData.AssertSuccess(Response);
        Assert.AreEqual(0, PostData.IntegerValue(Response, 'linesAdded'), 'No shipment is invented.');
        Request.Remove('customerNo');
        Response.Get('systemId', Token);
        Request.Add('systemId', Token);
        PostData.AssertSuccess(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1033, false));
        Numbers.Add('DUPLICATE');
        Numbers.Add('DUPLICATE');
        Request.Add('shipmentNos', Numbers);
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1033, false), 'InvalidParameterFormat');
        Request.Remove('allUninvoiced');
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1033, false), 'InvalidParameterFormat');
        Clear(Numbers);
        Numbers.Add(123);
        Request.Replace('shipmentNos', Numbers);
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1039, false), 'InvalidParameterFormat');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_BillToConflict_ExistingInvoiceUnchanged()
    var
        Order: Record "Service Header";
        Invoice: Record "Service Header";
        Shipment: Record "Service Shipment Header";
        Line: Record "Service Line";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        Request: JsonObject;
        Numbers: JsonArray;
    begin
        // Story #22 AC04 | Time: WorkDate | Risk: bill-to identity checked before any line is added.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Order, Order."Document Type"::Order, CustomerNo, ResourceNo);
        Fixture.Document(Invoice, Invoice."Document Type"::Invoice, CustomerNo, ResourceNo);
        Commit();
        PostData.AssertSuccess(PostData.Post(Order."No.", 'true', '', '', 1, 1033));
        Shipment.SetRange("Order No.", Order."No.");
        Shipment.FindFirst();
        Shipment."Bill-to Customer No." := 'OTHER-OWNED-BILLTO';
        Shipment.Modify(false);
        Commit();
        Request.Add('invoiceNo', Invoice."No.");
        Numbers.Add(Shipment."No.");
        Request.Add('shipmentNos', Numbers);
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Invoice.GetShipmentLines", Request, '', 1033, false), 'ConflictingIdentifiers');
        Line.SetRange("Document Type", Invoice."Document Type");
        Line.SetRange("Document No.", Invoice."No.");
        Assert.AreEqual(1, Line.Count(), 'Original invoice line only.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC04_NativePostingError_DocumentRetained()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Credit: Record "Service Cr.Memo Header";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
    begin
        // Story #22 AC04 | Time: WorkDate | Risk: native errors roll back document changes.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::"Credit Memo", CustomerNo, ResourceNo);
        Line.Get(Header."Document Type", Header."No.", 10000);
        Line."Gen. Prod. Posting Group" := '';
        Line.Modify();
        Commit();
        Data.AssertRefusal(InvokeAndCheckLog("Message Type ori"::"Service.Document.Post", Fixture.Request(Header, 1), Header."No.", 1033, false), 'BusinessCentralError');
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'Original document retained.');
        Credit.SetRange("Pre-Assigned No.", Header."No.");
        Assert.IsTrue(Credit.IsEmpty(), 'No partial posted document.');
        Fixture.Cleanup();
    end;
    [Test]
    procedure Scenario_AC01_InvoiceCustomerEntryRange()
    begin
        // Story #22 AC01 | Time: none | Risk: response range must include all matching entries.
        AssertCustomerEntryRange("Gen. Journal Document Type"::Invoice, 'Invoice');
    end;

    [Test]
    procedure Scenario_AC02_CreditCustomerEntryRange()
    begin
        // Story #22 AC02 | Time: none | Risk: credit memo ranges must not repeat the last entry.
        AssertCustomerEntryRange("Gen. Journal Document Type"::"Credit Memo", 'CreditMemo');
    end;

    local procedure AssertCustomerEntryRange(DocumentType: Enum "Gen. Journal Document Type"; TypeName: Text)
    var
        Entry: Record "Cust. Ledger Entry";
        PostProcessor: Codeunit "Svc Doc Post Proc ori";
        Response: JsonObject;
        Ranges: JsonObject;
        Token: JsonToken;
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        DocumentNo: Code[20];
        FirstEntryNo: Integer;
    begin
        Fixture.Create(CustomerNo, ResourceNo);
        DocumentNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(DocumentNo));
        // Component boundary: native posting rejects duplicate invoice identities before response assembly.
        // Seed two owned, zero-amount matching entries to exercise the response's multi-entry bounds.
        if Entry.FindLast() then
            FirstEntryNo := Entry."Entry No.";
        FirstEntryNo += 1;
        Entry.Init();
        Entry."Entry No." := FirstEntryNo;
        Entry."Customer No." := CustomerNo;
        Entry."Document No." := DocumentNo;
        Entry."Document Type" := DocumentType;
        Entry."Source Code" := 'XSM40';
        Entry.Insert(false);
        Entry."Entry No." += 1;
        Entry.Insert(false);
        // A later entry from another source must not extend the range.
        Entry."Entry No." += 1;
        Entry."Source Code" := 'XSM40OTHER';
        Entry.Insert(false);
        PostProcessor.AddPosted(Response, TypeName, DocumentNo, CreateGuid(), 20, 20, CustomerNo, 'XSM40');
        Response.Get('entryRanges', Token);
        Ranges := Token.AsObject();
        Assert.AreEqual(FirstEntryNo, PostData.IntegerValue(Ranges, 'customerFirst'), 'Range starts at the first matching entry.');
        Assert.AreEqual(FirstEntryNo + 1, PostData.IntegerValue(Ranges, 'customerLast'), 'Range ends at the last matching entry.');
        Fixture.Cleanup();
    end;

    local procedure InvokeAndCheckLog(MessageType: Enum "Message Type ori"; Request: JsonObject; Subject: Text; LanguageId: Integer; OmitCommit: Boolean): JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        Response: JsonObject;
        LogRequest: JsonObject;
        LogResponse: JsonObject;
        Token: JsonToken;
    begin
        Assert.IsFalse(OmitCommit, 'Billing tests exercise the persisted public dispatcher.');
        Request.WriteTo(RequestText);
        Input.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", CopyStr(Subject, 1, 250),
            'Owned service billing test #22', 'text/json', Input, TaskId, LanguageId, MessageId, Output, ContentType, ResponseTime);
        Assert.IsFalse(IsNullGuid(MessageId), 'Foundation returned the persisted message id.');
        Output.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Persisted response must be JSON.');
        if Data.TextValue(Response, 'status') = 'Error' then begin
            // Use Foundation's product API so the assertion also runs without Foundation Tests installed.
            LogRequest.Add('tableName', 'Message ori');
            LogRequest.Add('tableView', 'WHERE(Id=CONST(' + Format(MessageId, 0, 4) + '))');
            LogResponse := Data.Invoke("Message Type ori"::"Data.Records.Get", LogRequest, '', 1033, true);
            PostData.AssertSuccess(LogResponse);
            LogResponse.Get('noOfRecords', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Foundation retained this exact error message.');
        end;
        exit(Response);
    end;

}
