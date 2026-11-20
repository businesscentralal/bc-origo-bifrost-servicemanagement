namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Maintenance;
using Microsoft.Service.Setup;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves Service.FaultResolution.Suggest ranking, fault reporting level filtering and refusals on self-made raw data.</summary>
codeunit 97790 "Svc Fault Suggest Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Svc Test Data ori";

    [Test]
    procedure Scenario_AC01_TwoResolutions_HighestOccurrencesFirst()
    var
        ItemLine: Record "Service Item Line";
        FaultCode: Code[10];
        Response: JsonObject;
    begin
        // [GIVEN] Fault reporting level Fault, a line with a self-made fault and two self-made resolutions for it
        SetLevel(1);
        FaultCode := NewCode();
        CreateLine(ItemLine, FaultCode, '', '', '');
        InsertRelationship(FaultCode, '', '', 'R1-' + CopyStr(FaultCode, 1, 7), 3, '', false);
        InsertRelationship(FaultCode, '', '', 'R2-' + CopyStr(FaultCode, 1, 7), 7, '', true);
        InsertRelationship(NewCode(), '', '', NewCode(), 50, '', false);

        // [WHEN] Suggest runs for the line
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", LineRequest(ItemLine), '', 1033, true);

        // [THEN] Both resolutions return, highest occurrences first, and the other fault is not returned
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Suggest succeeds.');
        Assert.AreEqual('line', Data.TextValue(Response, 'source'), 'Line source.');
        Assert.AreEqual('Fault', Data.TextValue(Response, 'faultReportingLevel'), 'Level.');
        Assert.AreEqual(2, IntValue(Response, 'count'), 'Two suggestions.');
        AssertSuggestion(Response, 0, 'R2-' + CopyStr(FaultCode, 1, 7), 7);
        AssertSuggestion(Response, 1, 'R1-' + CopyStr(FaultCode, 1, 7), 3);
    end;

    [Test]
    procedure Scenario_AC01_CodesDirect_TopLimitsResult()
    var
        Request: JsonObject;
        Response: JsonObject;
        FaultCode: Code[10];
    begin
        // [GIVEN] Two resolutions for a fault
        SetLevel(1);
        FaultCode := NewCode();
        InsertRelationship(FaultCode, '', '', 'A-' + CopyStr(FaultCode, 1, 8), 2, '', false);
        InsertRelationship(FaultCode, '', '', 'B-' + CopyStr(FaultCode, 1, 8), 4, '', false);

        // [WHEN] Suggest runs with the code directly and top 1
        Request.Add('faultCode', LowerCase(FaultCode));
        Request.Add('top', 1);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);

        // [THEN] Only the most frequent one returns
        Assert.AreEqual('codes', Data.TextValue(Response, 'source'), 'Codes source.');
        Assert.AreEqual(1, IntValue(Response, 'count'), 'top limits the list.');
        AssertSuggestion(Response, 0, 'B-' + CopyStr(FaultCode, 1, 8), 4);
    end;

    [Test]
    procedure Scenario_AC02_FaultSymptom_OtherSymptomNotReturned()
    var
        ItemLine: Record "Service Item Line";
        FaultCode: Code[10];
        Symptom: Code[10];
        Response: JsonObject;
    begin
        // [GIVEN] Level Fault+Symptom and rows for the line's symptom and for another symptom
        SetLevel(2);
        FaultCode := NewCode();
        Symptom := NewCode();
        CreateLine(ItemLine, FaultCode, Symptom, '', '');
        InsertRelationship(FaultCode, Symptom, '', 'S-' + CopyStr(FaultCode, 1, 8), 1, '', false);
        InsertRelationship(FaultCode, NewCode(), '', 'O-' + CopyStr(FaultCode, 1, 8), 9, '', false);

        // [WHEN] Suggest runs for the line
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", LineRequest(ItemLine), '', 1033, true);

        // [THEN] Only the row with the line's symptom returns
        Assert.AreEqual('FaultSymptom', Data.TextValue(Response, 'faultReportingLevel'), 'Level.');
        Assert.AreEqual(1, IntValue(Response, 'count'), 'Other symptom excluded.');
        AssertSuggestion(Response, 0, 'S-' + CopyStr(FaultCode, 1, 8), 1);
    end;

    [Test]
    procedure Scenario_Edge_ServiceItemGroup_GroupAndBlankRowsOnly()
    var
        Request: JsonObject;
        Response: JsonObject;
        FaultCode: Code[10];
        GroupCode: Code[10];
    begin
        // [GIVEN] Rows for the group, without a group and for another group
        SetLevel(1);
        FaultCode := NewCode();
        GroupCode := NewCode();
        InsertRelationship(FaultCode, '', '', 'G-' + CopyStr(FaultCode, 1, 8), 5, GroupCode, false);
        InsertRelationship(FaultCode, '', '', 'N-' + CopyStr(FaultCode, 1, 8), 2, '', false);
        InsertRelationship(FaultCode, '', '', 'X-' + CopyStr(FaultCode, 1, 8), 9, NewCode(), false);

        // [WHEN] Suggest runs with the group
        Request.Add('faultCode', FaultCode);
        Request.Add('serviceItemGroupCode', GroupCode);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);

        // [THEN] The other group's row is not returned
        Assert.AreEqual(2, IntValue(Response, 'count'), 'Group and blank-group rows.');
        AssertSuggestion(Response, 0, 'G-' + CopyStr(FaultCode, 1, 8), 5);
        AssertSuggestion(Response, 1, 'N-' + CopyStr(FaultCode, 1, 8), 2);
    end;

    [Test]
    procedure Scenario_AC03_NoHistory_EmptySuccess()
    var
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
        Token: JsonToken;
    begin
        SetLevel(1);
        CreateLine(ItemLine, NewCode(), '', '', '');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", LineRequest(ItemLine), '', 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'No history is a success.');
        Assert.AreEqual(0, IntValue(Response, 'count'), 'Empty list.');
        Response.Get('suggestions', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Empty suggestions array.');
    end;

    [Test]
    procedure Scenario_AC03_LineWithoutFaultCode_PreconditionFailed()
    var
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
    begin
        SetLevel(1);
        CreateLine(ItemLine, '', '', '', '');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", LineRequest(ItemLine), '', 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Data.Records.Set'), 'nextStep names Data.Records.Set.');
    end;

    [Test]
    procedure Scenario_AC03_LevelNeedsSymptom_LineWithout_PreconditionFailed()
    var
        ItemLine: Record "Service Item Line";
        Response: JsonObject;
    begin
        SetLevel(2);
        CreateLine(ItemLine, NewCode(), '', '', '');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", LineRequest(ItemLine), '', 1039, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Data.Records.Set'), 'nextStep names Data.Records.Set in 1039.');
    end;

    [Test]
    procedure Scenario_Edge_FaultReportingOff_PreconditionFailed()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        SetLevel(0);
        Request.Add('faultCode', NewCode());
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC04_UnknownLine_RecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        SetLevel(1);
        Request.Add('documentNo', NewCode());
        Request.Add('serviceItemLineNo', 10000);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'RecordNotFound');
        Clear(Request);
        Request.Add('systemId', Format(CreateGuid(), 0, 4));
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC04_NeitherLineNorCodes_MissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('top', 5);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'MissingParameter');
    end;

    [Test]
    procedure Scenario_AC04_LineAndCodesDisagree_ConflictingIdentifiers()
    var
        ItemLine: Record "Service Item Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        SetLevel(1);
        CreateLine(ItemLine, NewCode(), '', '', '');
        Request := LineRequest(ItemLine);
        Request.Add('faultCode', NewCode());
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        // Matching codes are accepted.
        Request.Replace('faultCode', ItemLine."Fault Code");
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Matching codes agree with the line.');
        // A systemId of the same line with another line number conflicts.
        Clear(Request);
        Request.Add('systemId', Format(ItemLine.SystemId, 0, 4));
        Request.Add('serviceItemLineNo', ItemLine."Line No." + 1);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
    end;

    [Test]
    procedure Scenario_AC04_TopOutOfRange_InvalidParameterFormat()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        SetLevel(1);
        Request.Add('faultCode', NewCode());
        Request.Add('top', 0);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Request.Replace('top', 51);
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Request.Replace('top', '5');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
    end;

    [Test]
    procedure Scenario_AC04_UnknownKey_UnknownParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        SetLevel(1);
        Request.Add('faultCode', NewCode());
        Request.Add('resolutionCodeX', 'X');
        Response := Data.Invoke("Message Type ori"::"Service.FaultResolution.Suggest", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'UnknownParameter');
    end;

    /// <summary>Sets the service setup's fault reporting level by option index (0 None, 1 Fault, 2 Fault+Symptom, 3 with area).</summary>
    internal procedure SetLevel(Level: Integer)
    var
        Setup: Record "Service Mgt. Setup";
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert();
        end;
        Setup."Fault Reporting Level" := Level;
        Setup.Modify();
    end;

    /// <summary>Inserts a relationship row as raw data, with its own resolution code.</summary>
    internal procedure InsertRelationship(FaultCode: Code[10]; Symptom: Code[10]; FaultArea: Code[10]; Resolution: Code[10]; Occurrences: Integer; GroupCode: Code[10]; Manual: Boolean)
    var
        Relationship: Record "Fault/Resol. Cod. Relationship";
        ResolutionCode: Record "Resolution Code";
    begin
        if not ResolutionCode.Get(Resolution) then begin
            ResolutionCode.Code := Resolution;
            ResolutionCode.Description := 'Fix ' + Resolution;
            ResolutionCode.Insert();
        end;
        Relationship."Fault Code" := FaultCode;
        Relationship."Symptom Code" := Symptom;
        Relationship."Fault Area Code" := FaultArea;
        Relationship."Resolution Code" := Resolution;
        Relationship."Service Item Group Code" := GroupCode;
        Relationship.Occurrences := Occurrences;
        Relationship."Created Manually" := Manual;
        Relationship.Insert();
    end;

    local procedure CreateLine(var ItemLine: Record "Service Item Line"; FaultCode: Code[10]; Symptom: Code[10]; FaultArea: Code[10]; GroupCode: Code[10])
    var
        Header: Record "Service Header";
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        // Raw data: the codes are written without validation, as the story requires.
        ItemLine."Fault Code" := FaultCode;
        ItemLine."Symptom Code" := Symptom;
        ItemLine."Fault Area Code" := FaultArea;
        ItemLine."Service Item Group Code" := GroupCode;
        ItemLine.Modify();
    end;

    local procedure LineRequest(ItemLine: Record "Service Item Line"): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('documentNo', ItemLine."Document No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No.");
        exit(Request);
    end;

    local procedure AssertSuggestion(Response: JsonObject; Index: Integer; Resolution: Text; Occurrences: Integer)
    var
        Token: JsonToken;
        Entry: JsonObject;
    begin
        Response.Get('suggestions', Token);
        Token.AsArray().Get(Index, Token);
        Entry := Token.AsObject();
        Assert.AreEqual(Resolution, Data.TextValue(Entry, 'resolutionCode'), 'Resolution at ' + Format(Index));
        Assert.AreEqual(Occurrences, IntValue(Entry, 'occurrences'), 'Occurrences at ' + Format(Index));
        Assert.AreEqual('Fix ' + Resolution, Data.TextValue(Entry, 'description'), 'Description from the resolution code.');
    end;

    local procedure IntValue(Json: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Json.Get(Name, Token), 'Missing key: ' + Name);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Returns a unique 10-character code for self-made data.</summary>
    internal procedure NewCode(): Code[10]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10));
    end;
}
