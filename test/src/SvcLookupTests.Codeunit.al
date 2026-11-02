namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using Origo.Bifrost.ServiceManagement;
using System.TestLibraries.Utilities;

/// <summary>Exercises the shared lookup component without registering a message type or claiming dispatcher acceptance.</summary>
codeunit 97712 "Svc Lookup Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestData: Codeunit "Svc Test Data ori";
        Lookup: Codeunit "Svc Document Lookup ori";

    [Test]
    procedure Component_NumberResolvesOrder()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', Header."No.");
        AssertFound(Request, '', Header);
    end;

    [Test]
    procedure Component_SystemIdResolvesOrder()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        AssertFound(Request, '', Header);
    end;

    [Test]
    procedure Component_SubjectResolvesOrder()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Order);
        AssertFound(Request, Header."No.", Header);
    end;

    [Test]
    procedure Component_AllIdentifiersMustAgree()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', LowerCase(Header."No."));
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        AssertFound(Request, Header."No.", Header);
    end;

    [Test]
    procedure Component_CallerCanResolveQuote()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Quote);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        AssertFound(Request, '', Header);
    end;

    [Test]
    procedure Component_DifferentNumbersConflict()
    var
        Header: Record "Service Header";
        OtherHeader: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Order);
        TestData.CreateDocument(OtherHeader, OtherHeader."Document Type"::Order);
        Request.Add('no', Header."No.");
        Request.Add('systemId', Format(OtherHeader.SystemId, 0, 4));
        AssertLookupError(Request, '', 'ConflictingIdentifiers');
    end;

    [Test]
    procedure Component_ConflictingSubjectIsNotIgnored()
    var
        Header: Record "Service Header";
        Request: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Order);
        Request.Add('no', Header."No.");
        AssertLookupError(Request, 'X-DIFFERENT', 'ConflictingIdentifiers');
    end;

    [Test]
    procedure Component_WrongDocumentTypeIsRefused()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        TestData.CreateDocument(Header, Header."Document Type"::Quote);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Response := AssertLookupError(Request, '', 'InvalidParameter');
        Assert.AreEqual('systemId', TestData.TextValue(Response, 'parameter'), 'Wrong document type identifies the supplied GUID parameter.');
        Assert.AreEqual('Order', TestData.TextValue(Response, 'expected'), 'Expected type must be invariant.');
    end;

    [Test]
    procedure Component_MissingIdentifierIsRefused()
    var
        Request: JsonObject;
    begin
        AssertLookupError(Request, '', 'MissingParameter');
    end;

    [Test]
    procedure Component_UnknownNumberIsNotFound()
    var
        Request: JsonObject;
    begin
        Request.Add('no', CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-{}'), 1, 20));
        AssertLookupError(Request, '', 'RecordNotFound');
    end;

    [Test]
    procedure Component_MalformedGuidIsRefused()
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', 'not-a-guid');
        AssertLookupError(Request, '', 'InvalidParameterFormat');
    end;

    [Test]
    procedure Component_NumericNumberIsNotCoerced()
    var
        Request: JsonObject;
    begin
        Request.Add('no', 123);
        AssertLookupError(Request, '', 'InvalidParameterFormat');
    end;

    [Test]
    procedure Component_LongNumberIsNotTruncated()
    var
        Request: JsonObject;
    begin
        Request.Add('no', 'X123456789012345678901');
        AssertLookupError(Request, '', 'InvalidParameter');
    end;

    [Test]
    procedure Component_DeclaredErrorsAreCollected()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Request.Add('no', '');
        Request.Add('systemId', 'not-a-guid');
        Response := AssertLookupError(Request, '', 'MultipleErrors');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected errors must be returned.');
        Assert.AreEqual(2, Token.AsArray().Count(), 'Both declared parameter errors must be retained.');
    end;

    [Test]
    procedure Component_MissingIdentifierLocalizes()
    var
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := AssertLookupError(Request, '', 'MissingParameter');
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Sendu no eða systemId þjónustuskjals eða númer þess í subject.', TestData.TextValue(Response, 'error'), 'Icelandic message.');
        Assert.AreEqual('Sendu auðkennið á sniðinu sem describe_message_type lýsir.', TestData.TextValue(Response, 'nextStep'), 'Icelandic recovery guidance.');
    end;

    local procedure AssertFound(Request: JsonObject; Subject: Text; ExpectedHeader: Record "Service Header")
    var
        TempArgument: Record "Message Argument ori" temporary;
        ActualHeader: Record "Service Header";
    begin
        TempArgument.Insert();
        TempArgument.Subject := CopyStr(Subject, 1, MaxStrLen(TempArgument.Subject));
        TempArgument.SetRequestJson(Request);
        Assert.IsTrue(Lookup.FindDocument(TempArgument, ExpectedHeader."Document Type", ActualHeader), 'Expected document lookup to succeed.');
        Assert.AreEqual(ExpectedHeader.SystemId, ActualHeader.SystemId, 'Lookup must return the requested record.');
        Assert.AreEqual(ExpectedHeader."Release Status", ActualHeader."Release Status", 'Lookup must not change release state.');
    end;

    local procedure AssertLookupError(Request: JsonObject; Subject: Text; ErrorCode: Text): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Service Header";
        Response: JsonObject;
    begin
        TempArgument.Insert();
        TempArgument.Subject := CopyStr(Subject, 1, MaxStrLen(TempArgument.Subject));
        TempArgument.SetRequestJson(Request);
        Assert.IsFalse(Lookup.FindDocument(TempArgument, Header."Document Type"::Order, Header), 'Expected document lookup refusal.');
        Response := TempArgument.GetResponseJson();
        TestData.AssertRefusal(Response, ErrorCode);
        exit(Response);
    end;
}
