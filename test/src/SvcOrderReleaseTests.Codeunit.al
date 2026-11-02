namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Inventory.Setup;
using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Dispatcher acceptance for order release, identity validation and rollback.</summary>
codeunit 97705 "Svc Order Release Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_Release_ReturnsRecalculatedOrder()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', Header."No.");
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Release succeeded.');
        Assert.AreEqual('Order', Data.TextValue(Response, 'documentType'), 'Order scope.');
        Assert.AreEqual(Header."No.", Data.TextValue(Response, 'documentNo'), 'Number.');
        Assert.AreEqual(Format(Header.SystemId, 0, 4), Data.TextValue(Response, 'systemId'), 'Identity.');
        Assert.AreEqual(Header."Customer No.", Data.TextValue(Response, 'customerNo'), 'Customer.');
        Assert.AreEqual('Open', Data.TextValue(Response, 'releaseStatusBefore'), 'Before.');
        Assert.AreEqual('ReleasedToShip', Data.TextValue(Response, 'releaseStatusAfter'), 'After.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::"Released to Ship", Header."Release Status", 'Persisted release.');
        Header.CalcFields(Amount, "Amount Including VAT");
        Response.Get('amount', Token);
        Assert.AreEqual(Header.Amount, Token.AsValue().AsDecimal(), 'Recalculated amount.');
        Response.Get('amountIncludingVAT', Token);
        Assert.AreEqual(Header."Amount Including VAT", Token.AsValue().AsDecimal(), 'Recalculated VAT amount.');
    end;

    [Test]
    procedure Scenario_AC02_Release_BysystemId()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Identifier resolves.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::"Released to Ship", Header."Release Status", 'Released correct order.');
    end;

    [Test]
    procedure Scenario_AC02_Release_Bysubject()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, Header."No.", 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Identifier resolves.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::"Released to Ship", Header."Release Status", 'Released correct order.');
    end;

    [Test]
    procedure Scenario_AC03_NoQuantity_Refused()
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Line.SetRange("Document Type", Header."Document Type");
        Line.SetRange("Document No.", Header."No.");
        Line.ModifyAll(Quantity, 0);
        Request.Add('no', Header."No.");
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('nothing to release'), 'BC error text retained.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'No change.');
    end;

    [Test]
    procedure Scenario_AC04_LocationRequired_RollsBack()
    var
        Header: Record "Service Header";
        Setup: Record "Inventory Setup";
        PreviousMandatory: Boolean;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Setup.Get();
        PreviousMandatory := Setup."Location Mandatory";
        Setup."Location Mandatory" := true;
        Setup.Modify();
        Request.Add('no', Header."No.");
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Setup.Get();
        Setup."Location Mandatory" := PreviousMandatory;
        Setup.Modify();
        Commit();
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('Location Code'), 'BC TestField error retained.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Failed release rolled back.');
    end;

    [Test]
    procedure Scenario_AC07_RejectQuoteSystemId()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateHeader(Header, Header."Document Type"::"Quote");
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('systemId', Data.TextValue(Response, 'parameter'), 'Wrong-type parameter.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Wrong type unchanged.');
    end;

    [Test]
    procedure Scenario_AC07_RejectInvoiceSystemId()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateHeader(Header, Header."Document Type"::"Invoice");
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('systemId', Data.TextValue(Response, 'parameter'), 'Wrong-type parameter.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Wrong type unchanged.');
    end;

    [Test]
    procedure Scenario_AC07_RejectCreditMemoSystemId()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateHeader(Header, Header."Document Type"::"Credit Memo");
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('systemId', Data.TextValue(Response, 'parameter'), 'Wrong-type parameter.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Wrong type unchanged.');
    end;

    [Test]
    procedure Scenario_AC07_ConflictingIdentifiers()
    var
        Header: Record "Service Header";
        Other: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.CreateDocument(Other, Other."Document Type"::Order);
        Request.Add('no', Header."No.");
        Request.Add('systemId', Format(Other.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        Header.Get(Header."Document Type", Header."No.");
        Other.Get(Other."Document Type", Other."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'First unchanged.');
        Assert.AreEqual(Other."Release Status"::Open, Other."Release Status", 'Second unchanged.');
    end;

    [Test]
    procedure Scenario_AC08_Validation_BothTypes()
    var
        Types: List of [Enum "Message Type ori"];
        MessageType: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Unknown keys are dispatcher preflight; only declared errors aggregate (manufacturing8 lesson).
        Types.Add("Message Type ori"::"Service.Order.Release");
        Types.Add("Message Type ori"::"Service.Order.Reopen");
        foreach MessageType in Types do begin
            Clear(Request);
            Response := Data.Invoke(MessageType, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'MissingParameter');
            Request.Add('systemId', 'not-a-guid');
            Response := Data.Invoke(MessageType, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Request.Add('no', '');
            Response := Data.Invoke(MessageType, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'MultipleErrors');
            Clear(Request);
            Request.Add('no', 'X-NOT-FOUND');
            Response := Data.Invoke(MessageType, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'RecordNotFound');
            Request.Add('extra', 'x');
            Response := Data.Invoke(MessageType, Request, '', 1033, false);
            Data.AssertRefusal(Response, 'UnknownParameter');
            Assert.AreEqual('extra', Data.TextValue(Response, 'parameter'), 'Unknown key is explicit.');
        end;
    end;

    [Test]
    procedure Scenario_AC09_Release_CallerRollback()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        // Issue #4: independent fixture; exercise the public dispatcher and assert persisted state.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', Header."No.");
        Commit();
        asserterror ReleaseAndAbort(Request);
        Assert.ExpectedError('X caller aborted release');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'No commit from release.');
    end;

    local procedure ReleaseAndAbort(Request: JsonObject)
    var
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Release succeeded before rollback.');
        Error('X caller aborted release');
    end;
}
