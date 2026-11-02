namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;
using System.TestTools.TestRunner;

/// <summary>Wrong-type refusals name the actual document type in the caller's language.</summary>
codeunit 97715 "Svc Wrong Type Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_AC03_ReleaseQuote_NamesTypeInCallerLanguage()
    begin
        // Issue #10 AC1/AC3 | Time: none | Risk: None
        AssertQuoteRefusal("Message Type ori"::"Service.Order.Release");
    end;

    [Test]
    procedure Scenario_AC01_AC03_ReopenQuote_NamesTypeInCallerLanguage()
    begin
        // Issue #10 AC1/AC3 | Time: none | Risk: None
        AssertQuoteRefusal("Message Type ori"::"Service.Order.Reopen");
    end;

    [Test]
    procedure Scenario_AC02_StructuredFields_StayEnglish()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #10 AC2 | Time: none | Risk: None. Structured fields stay English at both languages.
        Data.CreateHeader(Header, Header."Document Type"::Quote);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();

        Response := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1039, false);
        AssertStructuredFields(Response);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Reopen", Request, '', 1033, false);
        AssertStructuredFields(Response);
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Wrong type leaves the quote unchanged.');
    end;

    [Test]
    procedure Scenario_AC12_SuiteUsesSessionRunner()
    var
        Suite: Record "AL Test Suite";
    begin
        // The new-company consent test starts a real session, which runner 130450 rejects.
        // The current run already chose its runner; this persists 130451 for the next run.
        Suite.Get('SERVICEMGT');
        if Suite."Test Runner Id" <> 130451 then begin
            Suite.Validate("Test Runner Id", 130451);
            Suite.Modify(true);
            Commit();
        end;
        Assert.AreEqual(130451, Suite."Test Runner Id", 'SERVICEMGT must use the standard non-isolated runner.');
    end;

    local procedure AssertQuoteRefusal(MessageType: Enum "Message Type ori")
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateHeader(Header, Header."Document Type"::Quote);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Commit();

        Response := Data.Invoke(MessageType, Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        AssertStructuredFields(Response);
        Assert.AreEqual(StrSubstNo('Service document %1 is not an Order (actual type: Quote).', Header."No."), Data.TextValue(Response, 'error'), 'English refusal.');
        Assert.AreEqual('Send the No. or SystemId of a service order.', Data.TextValue(Response, 'nextStep'), 'English recovery.');

        Response := Data.Invoke(MessageType, Request, '', 1039, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        AssertStructuredFields(Response);
        Assert.AreEqual(StrSubstNo('Þjónustuskjal %1 er ekki pöntun (raunveruleg gerð: %2).', Header."No.", 'Tilboð'), Data.TextValue(Response, 'error'), 'Icelandic refusal uses the base caption.');
        Assert.AreEqual('Sendu númer eða SystemId þjónustupöntunar.', Data.TextValue(Response, 'nextStep'), 'Icelandic recovery is unchanged.');
        Assert.IsFalse(Data.TextValue(Response, 'error').Contains('Quote'), 'Icelandic text must not keep the English enum name.');

        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Wrong type leaves the quote unchanged.');
    end;

    local procedure AssertStructuredFields(Response: JsonObject)
    begin
        Assert.AreEqual('systemId', Data.TextValue(Response, 'parameter'), 'Parameter stays systemId.');
        Assert.AreEqual('Order', Data.TextValue(Response, 'expected'), 'Expected stays the English enum name.');
    end;
}
