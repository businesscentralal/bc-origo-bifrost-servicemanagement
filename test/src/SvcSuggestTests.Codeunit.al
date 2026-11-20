namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Service.Resource.Suggest ranking, setup options and refusals (#27 AC01, AC02, AC04).</summary>
codeunit 97780 "Svc Suggest Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Data: Codeunit "Svc Test Data ori";
        Fixture: Codeunit "Svc Suggest Data ori";
        Assert: Codeunit "Library Assert";
        GroupNo: Code[20];
        Qualified: Code[20];
        Remote: Code[20];
        Busy: Code[20];
        Unskilled: Code[20];
        FirstDay: Date;
        OldSkills: Option "Code Shown","Warning Displayed","Not Used";
        OldZones: Option "Code Shown","Warning Displayed","Not Used";

    [Test]
    procedure Scenario_AC01_QualifiedInZoneFirst_AvailableHours()
    var
        Response: JsonObject;
        Resources: JsonArray;
    begin
        // [GIVEN] Skills and zones are used; four owned resources, one with 3 hours allocated
        Initialize(OldSkills::"Code Shown");
        // [WHEN] Suggest runs for the two-day period
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", LineRequest(true), '', 1033, true);
        Fixture.RestoreOptions(OldSkills, OldZones);
        // [THEN] Qualified in-zone resources come first, by available hours; the unskilled one is left out
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Suggest succeeds.');
        Assert.IsTrue(BoolValue(Response, 'skillsApplied'), 'Skills are applied.');
        Assert.IsTrue(BoolValue(Response, 'zonesApplied'), 'Zones are applied.');
        Resources := ResourcesOf(Response);
        Assert.AreEqual(3, Resources.Count(), 'Unqualified resources are left out by default.');
        AssertEntry(Resources, 0, Qualified, true, true, 16, 0, 16);
        AssertEntry(Resources, 1, Busy, true, true, 16, 3, 13);
        AssertEntry(Resources, 2, Remote, true, false, 16, 0, 16);
    end;

    [Test]
    procedure Scenario_AC01_IncludeUnqualifiedAndTop()
    var
        Request: JsonObject;
        Response: JsonObject;
        Resources: JsonArray;
    begin
        Initialize(OldSkills::"Code Shown");
        Request := LineRequest(true);
        Request.Add('includeUnqualified', true);
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Resources := ResourcesOf(Response);
        Assert.AreEqual(4, Resources.Count(), 'includeUnqualified returns every resource of the group.');
        AssertEntry(Resources, 3, Unskilled, false, true, 16, 0, 16);
        // [EDGE] top cuts the ranked list after the best entries
        Request.Add('top', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Fixture.RestoreOptions(OldSkills, OldZones);
        Resources := ResourcesOf(Response);
        Assert.AreEqual(1, Resources.Count(), 'top = 1 returns one resource.');
        AssertEntry(Resources, 0, Qualified, true, true, 16, 0, 16);
    end;

    [Test]
    procedure Scenario_SystemIdIdentifiesLine()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize(OldSkills::"Code Shown");
        Request.Add('systemId', Format(ItemLine.SystemId, 0, 4));
        Request.Add('dateFrom', Format(FirstDay, 0, 9));
        Request.Add('dateTo', Format(FirstDay + 1, 0, 9));
        Request.Add('resourceGroupNo', GroupNo);
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Fixture.RestoreOptions(OldSkills, OldZones);
        Assert.AreEqual(Header."No.", Data.TextValue(Response, 'documentNo'), 'The line resolves by SystemId.');
        Assert.AreEqual(3, ResourcesOf(Response).Count(), 'Same ranking as by number.');
    end;

    [Test]
    procedure Scenario_AC02_SkillsNotUsed_AllReturned_QualifiedNull()
    var
        Response: JsonObject;
        Resources: JsonArray;
        Entry: JsonToken;
        Token: JsonToken;
        Index: Integer;
    begin
        // [GIVEN] Resource Skills Option is Not Used
        Initialize(OldSkills::"Not Used");
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", LineRequest(true), '', 1033, true);
        Fixture.RestoreOptions(OldSkills, OldZones);
        // [THEN] Every resource is returned and qualified is reported as not applied
        Assert.IsFalse(BoolValue(Response, 'skillsApplied'), 'Skills are not applied.');
        Resources := ResourcesOf(Response);
        Assert.AreEqual(4, Resources.Count(), 'Skills do not filter when not used.');
        for Index := 0 to Resources.Count() - 1 do begin
            Resources.Get(Index, Entry);
            Entry.AsObject().Get('qualified', Token);
            Assert.IsTrue(Token.AsValue().IsNull(), 'qualified is null when skills are not used.');
        end;
        // In zone first, then available hours: Remote (outside the zone) is last
        Resources.Get(3, Entry);
        Assert.AreEqual(Remote, Data.TextValue(Entry.AsObject(), 'resourceNo'), 'Outside the zone ranks last.');
    end;

    [Test]
    procedure Scenario_AC04_Refusals()
    var
        Other: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
        Serialized: Text;
    begin
        Initialize(OldSkills::"Code Shown");
        // Unknown service item line
        Request.Add('documentNo', Header."No.");
        Request.Add('serviceItemLineNo', 999999);
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'RecordNotFound');
        Assert.AreEqual('serviceItemLineNo', Data.TextValue(Response, 'parameter'), 'The line number is named.');
        // Unknown systemId
        Clear(Request);
        Request.Add('systemId', Format(CreateGuid(), 0, 4));
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'RecordNotFound');
        // Missing line
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'MissingParameter');
        Assert.AreEqual('serviceItemLineNo', Data.TextValue(Response, 'parameter'), 'The missing line is named.');
        Clear(Request);
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'MissingParameter');
        // Period over 31 days
        Request := LineRequest(false);
        Request.Add('dateFrom', '2026-01-01');
        Request.Add('dateTo', '2026-02-01');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Assert.AreEqual('dateTo', Data.TextValue(Response, 'parameter'), 'dateTo is named.');
        // dateTo before dateFrom
        Request := LineRequest(false);
        Request.Add('dateFrom', '2026-01-10');
        Request.Add('dateTo', '2026-01-09');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        // Not a date
        Request := LineRequest(false);
        Request.Add('dateFrom', '10.01.2026');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        // Conflicting identifiers
        Data.CreateDocument(Other, Other."Document Type"::Order);
        Clear(Request);
        Request.Add('systemId', Format(ItemLine.SystemId, 0, 4));
        Request.Add('documentNo', Other."No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No.");
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'ConflictingIdentifiers');
        // Unknown resource group
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No.");
        Request.Add('resourceGroupNo', 'NOGROUP-X1');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'RecordNotFound');
        // top out of range
        Request := LineRequest(false);
        Request.Add('top', 101);
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameter');
        // Unknown key: a plain call answers with a warning, a strict call refuses
        Request := LineRequest(false);
        Request.Add('extra', 'x');
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('extra'), 'The unknown key is reported.');
        Response := InvokeStrict(Request);
        Fixture.RestoreOptions(OldSkills, OldZones);
        Data.AssertRefusal(Response, 'UnknownParameter');
        Assert.AreEqual('extra', Data.TextValue(Response, 'parameter'), 'The unknown key is named.');
    end;

    [Test]
    procedure Scenario_QuoteLine_Refused()
    var
        Quote: Record "Service Header";
        QuoteLine: Record "Service Item Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(Quote, Quote."Document Type"::Quote);
        QuoteLine.SetRange("Document Type", Quote."Document Type");
        QuoteLine.SetRange("Document No.", Quote."No.");
        QuoteLine.FindFirst();
        Request.Add('systemId', Format(QuoteLine.SystemId, 0, 4));
        Response := Data.Invoke("Message Type ori"::"Service.Resource.Suggest", Request, '', 1033, true);
        Data.AssertRefusal(Response, 'InvalidParameter');
    end;

    local procedure Initialize(Skills: Option "Code Shown","Warning Displayed","Not Used")
    begin
        // Record globals keep their cached setup between tests, so start from clean records.
        Clear(Header);
        Clear(ItemLine);
        FirstDay := DMY2Date(2, 3, 2026);
        Fixture.Create(Header, ItemLine, GroupNo, Qualified, Remote, Busy, Unskilled, FirstDay);
        Fixture.SetOptions(Skills, OldZones::"Code Shown", OldSkills, OldZones);
    end;

    local procedure InvokeStrict(Request: JsonObject): JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        Response: JsonObject;
    begin
        Request.WriteTo(RequestText);
        Input.AddText(RequestText);
        Dispatcher.ExecuteStrict("Message Type ori"::"Service.Resource.Suggest", "Message Version ori"::"1.0", '', '', 'text/json', Input, Output, ContentType, true);
        Output.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
        exit(Response);
    end;

    local procedure LineRequest(WithPeriod: Boolean) Request: JsonObject
    begin
        Request.Add('documentNo', Header."No.");
        Request.Add('serviceItemLineNo', ItemLine."Line No.");
        Request.Add('resourceGroupNo', GroupNo);
        if WithPeriod then begin
            Request.Add('dateFrom', Format(FirstDay, 0, 9));
            Request.Add('dateTo', Format(FirstDay + 1, 0, 9));
        end;
    end;

    local procedure ResourcesOf(Response: JsonObject): JsonArray
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get('resources', Token), 'Response has resources.');
        exit(Token.AsArray());
    end;

    local procedure BoolValue(Response: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure DecimalValue(Entry: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Entry.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsDecimal());
    end;

    local procedure AssertEntry(Resources: JsonArray; Index: Integer; ResourceNo: Code[20]; IsQualified: Boolean; InZone: Boolean; Capacity: Decimal; Allocated: Decimal; Available: Decimal)
    var
        Token: JsonToken;
        Entry: JsonObject;
    begin
        Resources.Get(Index, Token);
        Entry := Token.AsObject();
        Assert.AreEqual(ResourceNo, Data.TextValue(Entry, 'resourceNo'), StrSubstNo('Resource at rank %1.', Index + 1));
        Assert.AreEqual(GroupNo, Data.TextValue(Entry, 'resourceGroupNo'), 'Resource group.');
        Assert.AreEqual(IsQualified, BoolValue(Entry, 'qualified'), 'qualified of ' + ResourceNo);
        Assert.AreEqual(InZone, BoolValue(Entry, 'inServiceZone'), 'inServiceZone of ' + ResourceNo);
        Assert.AreEqual(Capacity, DecimalValue(Entry, 'capacity'), 'capacity of ' + ResourceNo);
        Assert.AreEqual(Allocated, DecimalValue(Entry, 'allocatedHours'), 'allocatedHours of ' + ResourceNo);
        Assert.AreEqual(Available, DecimalValue(Entry, 'availableHours'), 'availableHours of ' + ResourceNo);
    end;
}
