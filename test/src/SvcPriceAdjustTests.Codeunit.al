namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Pricing;
using Microsoft.Service.Test;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves Service.Order.AdjustPrice spreads, caps, previews and resets prices on self-made service documents and refuses bad input without changes.</summary>
codeunit 97770 "Svc Price Adjust Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC01_Fixed200_SpreadsAndResetRestores()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
        Before: Decimal;
        ItemPrice: Decimal;
        ResourcePrice: Decimal;
        CostPrice: Decimal;
    begin
        // [GIVEN] A self-made order with an item, a resource and a cost line and a Fixed 200 price group
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 0, 200);
        Before := LinesTotal(ItemLine);
        Assert.AreNotEqual(200, Before, 'The fixture must start away from the target.');
        ItemPrice := UnitPrice(ItemLine, "Service Line Type"::Item);
        ResourcePrice := UnitPrice(ItemLine, "Service Line Type"::Resource);
        CostPrice := UnitPrice(ItemLine, "Service Line Type"::Cost);

        // [WHEN] The price is adjusted
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", LineRequest(ItemLine), '', 1033, false);

        // [THEN] The three lines add up to 200 and are marked adjusted
        AssertSuccess(Response);
        Assert.AreEqual('Fixed', Data.TextValue(Response, 'adjustmentType'), 'Adjustment type.');
        Assert.IsTrue(BoolValue(Response, 'changed'), 'Prices were written.');
        Assert.AreEqual(200, LinesTotal(ItemLine), 'The lines add up to the fixed price.');
        Assert.AreEqual(3, AdjustedCount(ItemLine), 'Every line is adjusted.');
        Assert.AreEqual(3, LineCount(Response), 'The response lists each line.');
        AssertNoWorkingRows();

        // [WHEN] The adjustment is reset
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", ResetRequest(ItemLine), '', 1033, false);

        // [THEN] The original prices are back and no line is marked adjusted
        AssertSuccess(Response);
        Assert.AreEqual(Before, LinesTotal(ItemLine), 'Reset restores the total.');
        Assert.AreEqual(ItemPrice, UnitPrice(ItemLine, "Service Line Type"::Item), 'Item price restored.');
        Assert.AreEqual(ResourcePrice, UnitPrice(ItemLine, "Service Line Type"::Resource), 'Resource price restored.');
        Assert.AreEqual(CostPrice, UnitPrice(ItemLine, "Service Line Type"::Cost), 'Cost price restored.');
        Assert.AreEqual(0, AdjustedCount(ItemLine), 'No line stays adjusted.');
        AssertNoWorkingRows();
    end;

    [Test]
    procedure Scenario_AC01_Quote_FixedPrice()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A self-made service quote with a Fixed 150 price group
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Quote, 0, 150);
        Request := LineRequest(ItemLine);
        Request.Add('documentType', 'Quote');

        // [WHEN] The price is adjusted with Omit Commit
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", Request, '', 1033, true);

        // [THEN] The quote lines add up to 150
        AssertSuccess(Response);
        Assert.AreEqual('Quote', Data.TextValue(Response, 'documentType'), 'Quote is adjusted.');
        Assert.AreEqual(150, LinesTotal(ItemLine), 'The quote lines add up to the fixed price.');
        AssertNoWorkingRows();
    end;

    [Test]
    procedure Scenario_AC02_Maximum_PreviewThenCap()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Request: JsonObject;
        Preview: JsonObject;
        Response: JsonObject;
        Before: Decimal;
        Cap: Decimal;
        PreviewText: Text;
        ResponseText: Text;
    begin
        // [GIVEN] A Maximum price group below the order total
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 1, 1);
        Before := LinesTotal(ItemLine);
        Cap := Round(Before / 2, 0.01);
        SetSetupAmount(ItemLine, Cap);

        // [WHEN] The adjustment is previewed
        Request := LineRequest(ItemLine);
        Request.Add('preview', true);
        Preview := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", Request, '', 1033, false);

        // [THEN] The capped numbers come back and nothing is written
        AssertSuccess(Preview);
        Assert.IsFalse(BoolValue(Preview, 'changed'), 'Preview writes nothing.');
        Assert.AreEqual(Cap, DecimalValue(Preview, 'totalAfter'), 'Preview shows the cap.');
        Assert.AreEqual(Before, LinesTotal(ItemLine), 'Preview leaves the prices.');
        Assert.AreEqual(0, AdjustedCount(ItemLine), 'Preview marks nothing.');
        AssertNoWorkingRows();

        // [WHEN] The adjustment is applied
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", LineRequest(ItemLine), '', 1033, false);

        // [THEN] The total is reduced to the cap with the same numbers the preview returned
        AssertSuccess(Response);
        Assert.AreEqual(Cap, LinesTotal(ItemLine), 'The total is capped.');
        Assert.AreEqual(Cap, DecimalValue(Response, 'totalAfter'), 'Response total.');
        PreviewText := LinesText(Preview);
        ResponseText := LinesText(Response);
        Assert.AreEqual(PreviewText, ResponseText, 'Preview and apply return the same new prices.');
        AssertNoWorkingRows();
    end;

    [Test]
    procedure Scenario_AC02_Maximum_BelowCapUnchanged()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
        Before: Decimal;
    begin
        // [GIVEN] A Maximum price group above the order total
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 1, 1);
        Before := LinesTotal(ItemLine);
        SetSetupAmount(ItemLine, Before * 10);

        // [WHEN] The price is adjusted
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", LineRequest(ItemLine), '', 1033, false);

        // [THEN] Nothing changes
        AssertSuccess(Response);
        Assert.IsFalse(BoolValue(Response, 'changed'), 'Below the cap nothing is written.');
        Assert.AreEqual(Before, LinesTotal(ItemLine), 'The total is left unchanged.');
        Assert.AreEqual(0, AdjustedCount(ItemLine), 'No line is marked adjusted.');
        AssertNoWorkingRows();
    end;

    [Test]
    procedure Scenario_AC02_Maximum_PricesInclVAT_NetBelowExclusiveCap()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Line: Record "Service Line";
        Request: JsonObject;
        Response: JsonObject;
        Net: Decimal;
        Gross: Decimal;
        Cap: Decimal;
    begin
        // [GIVEN] A prices-including-VAT order whose net total is below a VAT-exclusive maximum and whose gross total is above it
        CreateDocument(Header, ItemLine, Header."Document Type"::Order, 1, 1, true);
        FilterLines(ItemLine, Line);
        Line.CalcSums("Line Amount");
        Gross := Line."Line Amount";
        Line.FindSet();
        repeat
            Net += Round(Line."Line Amount" / (1 + Line."VAT %" / 100), 0.01);
        until Line.Next() = 0;
        Assert.IsTrue(Gross - Net > 1, 'The fixture needs VAT on the lines.');
        Cap := Round((Net + Gross) / 2, 1);
        SetSetupAmount(ItemLine, Cap);

        // [WHEN] The price is previewed and then adjusted
        Request := LineRequest(ItemLine);
        Request.Add('preview', true);
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", Request, '', 1033, false);

        // [THEN] Both leave the order unchanged, because the net total is already below the cap
        AssertNoOpMatchesStored(Response, ItemLine, Net);
        Assert.AreEqual(Net, DecimalValue(Response, 'comparedTotal'), 'The cap is compared with the net total.');
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", LineRequest(ItemLine), '', 1033, false);
        AssertNoOpMatchesStored(Response, ItemLine, Net);
        Assert.AreEqual(Gross, LinesTotal(ItemLine), 'The gross total is left unchanged.');
        Assert.AreEqual(0, AdjustedCount(ItemLine), 'No line is marked adjusted.');
        AssertNoWorkingRows();
    end;

    [Test]
    procedure Scenario_AC02_Maximum_DiscountsExcluded_NoOpReportsStoredPrices()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Request: JsonObject;
        Response: JsonObject;
        Undiscounted: Decimal;
        Stored: Decimal;
    begin
        // [GIVEN] Discounted lines, a setup that excludes discounts, and a maximum above the undiscounted total
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 1, 1);
        Undiscounted := LinesTotal(ItemLine);
        SetLineDiscounts(ItemLine, 10);
        Stored := LinesTotal(ItemLine);
        Assert.IsTrue(Stored < Undiscounted, 'The fixture lines carry a discount.');
        SetIncludeDiscounts(ItemLine, false);
        SetSetupAmount(ItemLine, Undiscounted * 1.5);

        // [WHEN] The price is previewed and then adjusted
        Request := LineRequest(ItemLine);
        Request.Add('preview', true);
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", Request, '', 1033, false);

        // [THEN] The responses report the stored discounted prices, not the undiscounted calculation basis
        AssertNoOpMatchesStored(Response, ItemLine, Stored);
        Assert.AreEqual(Undiscounted, DecimalValue(Response, 'comparedTotal'), 'The comparison uses the undiscounted basis.');
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", LineRequest(ItemLine), '', 1033, false);
        AssertNoOpMatchesStored(Response, ItemLine, Stored);
        Assert.AreEqual(Stored, LinesTotal(ItemLine), 'The discounted lines are left unchanged.');
        Assert.AreEqual(0, AdjustedCount(ItemLine), 'No line is marked adjusted.');
        AssertNoWorkingRows();
    end;

    [Test]
    procedure Scenario_AC04_InvoicedLine_PreconditionFailed()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Line: Record "Service Line";
        Before: Decimal;
    begin
        // [GIVEN] An order whose item line is already partly invoiced
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 0, 200);
        FindLine(ItemLine, "Service Line Type"::Item, Line);
        Line."Quantity Invoiced" := 1;
        Line.Modify();
        Before := LinesTotal(ItemLine);

        // [WHEN/THEN] The adjustment is refused and nothing changes
        AssertRefusedUnchanged(LineRequest(ItemLine), 'PreconditionFailed', ItemLine, Before);
    end;

    [Test]
    procedure Scenario_AC04_MissingGroup_PreconditionFailedWithNextStep()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
        Before: Decimal;
    begin
        // [GIVEN] An order whose service item line has no service price group
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 0, 200);
        ItemLine."Service Price Group Code" := '';
        ItemLine.Modify();
        Before := LinesTotal(ItemLine);

        // [WHEN] The price is adjusted
        Response := AssertRefusedUnchanged(LineRequest(ItemLine), 'PreconditionFailed', ItemLine, Before);

        // [THEN] The next step names how to set the group
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Data.Records.Set'), 'nextStep names Data.Records.Set.');
    end;

    [Test]
    procedure Scenario_AC04_InvalidInput_RefusedUnchanged()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Request: JsonObject;
        Before: Decimal;
    begin
        // [GIVEN] An adjustable order
        CreateAdjustableDocument(Header, ItemLine, Header."Document Type"::Order, 0, 200);
        Before := LinesTotal(ItemLine);

        // [WHEN/THEN] Unknown line
        Request.Add('documentNo', Header."No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No." + 99999);
        AssertRefusedUnchanged(Request, 'RecordNotFound', ItemLine, Before);

        // [WHEN/THEN] Missing line
        Clear(Request);
        Request.Add('preview', true);
        AssertRefusedUnchanged(Request, 'MissingParameter', ItemLine, Before);

        // [WHEN/THEN] Conflicting identifiers
        Clear(Request);
        Request.Add('systemId', Format(ItemLine.SystemId, 0, 4));
        Request.Add('serviceItemLineNo', ItemLine."Line No." + 1);
        AssertRefusedUnchanged(Request, 'ConflictingIdentifiers', ItemLine, Before);

        // [WHEN/THEN] Non-boolean flag
        Request := LineRequest(ItemLine);
        Request.Add('preview', 'yes');
        AssertRefusedUnchanged(Request, 'InvalidParameterFormat', ItemLine, Before);

        // [WHEN/THEN] Unknown key
        Request := LineRequest(ItemLine);
        Request.Add('amount', 100);
        AssertRefusedUnchanged(Request, 'UnknownParameter', ItemLine, Before);

        // [WHEN/THEN] Reset without an adjustment
        AssertRefusedUnchanged(ResetRequest(ItemLine), 'PreconditionFailed', ItemLine, Before);
    end;

    /// <summary>Creates a service document with an item, a resource and a cost line on one service item line, and a price group setup of the given type and amount.</summary>
    procedure CreateAdjustableDocument(var Header: Record "Service Header"; var ItemLine: Record "Service Item Line"; DocumentType: Enum "Service Document Type"; AdjustmentType: Option "Fixed",Maximum,Minimum; Amount: Decimal)
    begin
        CreateDocument(Header, ItemLine, DocumentType, AdjustmentType, Amount, false);
    end;

    local procedure CreateDocument(var Header: Record "Service Header"; var ItemLine: Record "Service Item Line"; DocumentType: Enum "Service Document Type"; AdjustmentType: Option "Fixed",Maximum,Minimum; Amount: Decimal; PricesInclVAT: Boolean)
    var
        Customer: Record Customer;
        Item: Record Item;
        Resource: Record Resource;
        ServiceItem: Record "Service Item";
        ServiceCost: Record "Service Cost";
        PriceGroup: Record "Service Price Group";
        AdjustmentGroup: Record "Service Price Adjustment Group";
        Setup: Record "Serv. Price Group Setup";
        Sales: Codeunit "Library - Sales";
        Inventory: Codeunit "Library - Inventory";
        Resources: Codeunit "Library - Resource";
        Service: Codeunit "Library - Service";
    begin
        Data.SetupNumbering();
        Sales.CreateCustomer(Customer);
        Service.CreateServiceHeader(Header, DocumentType, Customer."No.");
        if PricesInclVAT then begin
            Header.Validate("Prices Including VAT", true);
            Header.Modify(true);
        end;
        Service.CreateServiceItem(ServiceItem, Customer."No.");
        Service.CreateServiceItemLine(ItemLine, Header, ServiceItem."No.");
        Inventory.CreateItem(Item);
        Item.Validate("Unit Price", 10);
        Item.Modify(true);
        Resources.CreateResource(Resource, Customer."VAT Bus. Posting Group");
        Resource.Validate("Unit Price", 10);
        Resource.Modify(true);
        Service.CreateServiceCost(ServiceCost);
        ServiceCost.Validate("Default Unit Price", 50);
        ServiceCost.Modify(true);
        AddLine(Header, ItemLine, "Service Line Type"::Item, Item."No.", 2, 10);
        AddLine(Header, ItemLine, "Service Line Type"::Resource, Resource."No.", 3, 10);
        AddLine(Header, ItemLine, "Service Line Type"::Cost, ServiceCost.Code, 1, 50);

        Service.CreateServicePriceGroup(PriceGroup);
        Service.CreateServPriceAdjustmentGroup(AdjustmentGroup);
        Setup.Init();
        Setup."Service Price Group Code" := PriceGroup.Code;
        Setup."Starting Date" := 0D;
        Setup."Serv. Price Adjmt. Gr. Code" := AdjustmentGroup.Code;
        Setup."Adjustment Type" := AdjustmentType;
        Setup.Amount := Amount;
        Setup."Include Discounts" := true;
        Setup."Include VAT" := false;
        Setup.Insert(true);

        ItemLine.Get(ItemLine."Document Type", ItemLine."Document No.", ItemLine."Line No.");
        ItemLine.Validate("Service Price Group Code", PriceGroup.Code);
        ItemLine.Modify(true);
        Assert.AreEqual(AdjustmentGroup.Code, ItemLine."Serv. Price Adjmt. Gr. Code", 'The service item line takes the adjustment group from the setup.');
    end;

    local procedure AddLine(Header: Record "Service Header"; ItemLine: Record "Service Item Line"; LineType: Enum "Service Line Type"; No: Code[20]; Quantity: Decimal; Price: Decimal)
    var
        Line: Record "Service Line";
        Service: Codeunit "Library - Service";
    begin
        Service.CreateServiceLineWithQuantity(Line, Header, LineType, No, Quantity);
        Line.Validate("Service Item Line No.", ItemLine."Line No.");
        if Line."Unit Price" = 0 then
            Line.Validate("Unit Price", Price);
        Line.Modify(true);
    end;

    /// <summary>Changes the amount of the price group setup used by the service item line.</summary>
    procedure SetSetupAmount(ItemLine: Record "Service Item Line"; Amount: Decimal)
    var
        Setup: Record "Serv. Price Group Setup";
    begin
        Setup.SetRange("Service Price Group Code", ItemLine."Service Price Group Code");
        Setup.FindFirst();
        Setup.Amount := Amount;
        Setup.Modify();
    end;

    local procedure SetIncludeDiscounts(ItemLine: Record "Service Item Line"; IncludeDiscounts: Boolean)
    var
        Setup: Record "Serv. Price Group Setup";
    begin
        Setup.SetRange("Service Price Group Code", ItemLine."Service Price Group Code");
        Setup.FindFirst();
        Setup."Include Discounts" := IncludeDiscounts;
        Setup.Modify();
    end;

    local procedure SetLineDiscounts(ItemLine: Record "Service Item Line"; DiscountPct: Decimal)
    var
        Line: Record "Service Line";
    begin
        FilterLines(ItemLine, Line);
        Line.FindSet(true);
        repeat
            Line.Validate("Line Discount %", DiscountPct);
            Line.Modify(true);
        until Line.Next() = 0;
    end;

    /// <summary>Asserts a no-op response: nothing changed, totals equal, and every line reports its stored unit price and line amount as both old and new.</summary>
    local procedure AssertNoOpMatchesStored(Response: JsonObject; ItemLine: Record "Service Item Line"; StoredTotal: Decimal)
    var
        Line: Record "Service Line";
        Token: JsonToken;
        Entry: JsonToken;
        Value: JsonToken;
        Object: JsonObject;
    begin
        AssertSuccess(Response);
        Assert.IsFalse(BoolValue(Response, 'changed'), 'A total within the limit is not written.');
        Assert.AreEqual(StoredTotal, DecimalValue(Response, 'totalBefore'), 'totalBefore is the stored total.');
        Assert.AreEqual(StoredTotal, DecimalValue(Response, 'totalAfter'), 'totalAfter equals totalBefore when nothing is adjusted.');
        Response.Get('lines', Token);
        Assert.AreEqual(3, Token.AsArray().Count(), 'Every covered line is reported.');
        foreach Entry in Token.AsArray() do begin
            Object := Entry.AsObject();
            Object.Get('lineNo', Value);
            Line.Get(ItemLine."Document Type", ItemLine."Document No.", Value.AsValue().AsInteger());
            Assert.AreEqual(Line."Unit Price", DecimalValue(Object, 'oldUnitPrice'), 'oldUnitPrice is the stored unit price.');
            Assert.AreEqual(Line."Unit Price", DecimalValue(Object, 'newUnitPrice'), 'newUnitPrice is the stored unit price.');
            Assert.AreEqual(Line."Line Amount", DecimalValue(Object, 'oldAmount'), 'oldAmount is the stored line amount.');
            Assert.AreEqual(Line."Line Amount", DecimalValue(Object, 'newAmount'), 'newAmount is the stored line amount.');
        end;
    end;

    /// <summary>Builds a request for the service item line.</summary>
    procedure LineRequest(ItemLine: Record "Service Item Line"): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('documentNo', ItemLine."Document No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No.");
        exit(Request);
    end;

    local procedure ResetRequest(ItemLine: Record "Service Item Line"): JsonObject
    var
        Request: JsonObject;
    begin
        Request := LineRequest(ItemLine);
        Request.Add('reset', true);
        exit(Request);
    end;

    /// <summary>Sums Line Amount of the service lines on the service item line.</summary>
    procedure LinesTotal(ItemLine: Record "Service Item Line"): Decimal
    var
        Line: Record "Service Line";
    begin
        FilterLines(ItemLine, Line);
        Line.CalcSums("Line Amount");
        exit(Line."Line Amount");
    end;

    /// <summary>Counts the service lines marked adjusted.</summary>
    procedure AdjustedCount(ItemLine: Record "Service Item Line"): Integer
    var
        Line: Record "Service Line";
    begin
        FilterLines(ItemLine, Line);
        Line.SetRange("Price Adjmt. Status", Line."Price Adjmt. Status"::Adjusted);
        exit(Line.Count());
    end;

    /// <summary>Asserts the real working table is empty.</summary>
    procedure AssertNoWorkingRows()
    var
        Working: Record "Service Line Price Adjmt.";
    begin
        Assert.IsTrue(Working.IsEmpty(), 'No Service Line Price Adjmt. rows may exist.');
    end;

    local procedure UnitPrice(ItemLine: Record "Service Item Line"; LineType: Enum "Service Line Type"): Decimal
    var
        Line: Record "Service Line";
    begin
        FindLine(ItemLine, LineType, Line);
        exit(Line."Unit Price");
    end;

    local procedure FindLine(ItemLine: Record "Service Item Line"; LineType: Enum "Service Line Type"; var Line: Record "Service Line")
    begin
        FilterLines(ItemLine, Line);
        Line.SetRange(Type, LineType);
        Line.FindFirst();
    end;

    local procedure FilterLines(ItemLine: Record "Service Item Line"; var Line: Record "Service Line")
    begin
        Line.SetRange("Document Type", ItemLine."Document Type");
        Line.SetRange("Document No.", ItemLine."Document No.");
        Line.SetRange("Service Item Line No.", ItemLine."Line No.");
    end;

    local procedure AssertRefusedUnchanged(Request: JsonObject; Code: Text; ItemLine: Record "Service Item Line"; Before: Decimal): JsonObject
    var
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", Request, '', 1033, false);
        Data.AssertRefusal(Response, Code);
        Assert.AreEqual(Before, LinesTotal(ItemLine), 'Nothing changed after ' + Code);
        Assert.AreEqual(0, AdjustedCount(ItemLine), 'No line marked after ' + Code);
        AssertNoWorkingRows();
        exit(Response);
    end;

    /// <summary>Asserts a Success response and shows the response on failure.</summary>
    procedure AssertSuccess(Response: JsonObject)
    var
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), CopyStr(Serialized, 1, 900));
    end;

    local procedure BoolValue(Response: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure DecimalValue(Response: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsDecimal());
    end;

    local procedure LineCount(Response: JsonObject): Integer
    var
        Token: JsonToken;
    begin
        Response.Get('lines', Token);
        exit(Token.AsArray().Count());
    end;

    local procedure LinesText(Response: JsonObject): Text
    var
        Token: JsonToken;
        Item: JsonToken;
        Value: JsonToken;
        Result: Text;
    begin
        Response.Get('lines', Token);
        foreach Item in Token.AsArray() do begin
            Item.AsObject().Get('newUnitPrice', Value);
            Result += Format(Value.AsValue().AsDecimal(), 0, 9) + '/';
            Item.AsObject().Get('newAmount', Value);
            Result += Format(Value.AsValue().AsDecimal(), 0, 9) + ';';
        end;
        exit(Result);
    end;
}
