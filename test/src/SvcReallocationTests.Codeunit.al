namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Foundation.AuditCodes;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Microsoft.Service.Maintenance;
using Microsoft.Service.Setup;
using Microsoft.Service.Test;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Reallocation keeps the active entry, stores the reason and rolls back a failed move.</summary>
codeunit 97726 "Svc Reallocation Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_Reallocate_KeepsEntryAndReason()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        History: Record "Service Order Allocation";
        First: Record Resource;
        Second: Record Resource;
        Reason: Record "Reason Code";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
        Token: JsonToken;
    begin
        Activate(Header, Alloc, First, Zones, Skills);
        Data.CreateResourceFor(Header."Customer No.", Second);
        CreateReason(Reason);
        SetNeutralRepairStatus(Header);
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Second."No.", Reason.Code, '', '');
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Reallocated.');
        Assert.AreEqual('true', Data.TextValue(Response, 'reallocated'), 'Marked as moved.');
        Assert.AreEqual(Format(Alloc."Entry No."), Data.TextValue(Response, 'entryNo'), 'Active entry number is unchanged.');
        Assert.AreEqual('Canceled', Data.TextValue(Response, 'previousStatus'), 'Previous entry is canceled.');
        Response.Get('previousEntryNo', Token);
        Assert.AreNotEqual(Alloc."Entry No.", Token.AsValue().AsInteger(), 'History has its own entry number.');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual(Second."No.", Alloc."Resource No.", 'Active entry has the new resource.');
        Assert.AreEqual(Reason.Code, Alloc."Reason Code", 'Reason is stored on the active entry.');
        Assert.AreEqual(Alloc.Status::Active, Alloc.Status, 'Active entry stays active.');
        History.Get(Token.AsValue().AsInteger());
        Assert.AreEqual(First."No.", History."Resource No.", 'History keeps the old resource.');
        Assert.AreEqual(History.Status::Canceled, History.Status, 'History is canceled.');
        Assert.AreEqual('', History."Reason Code", 'Old reason stays on the history entry.');
    end;

    [Test]
    procedure Scenario_ReallocationNeeded_AndServiceStarted()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Second: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        // Group 2 quote conversion is not merged, so the test prepares Reallocation Needed itself.
        Activate(Header, Alloc, Second, Zones, Skills);
        Data.CreateResourceFor(Header."Customer No.", Second);
        SetNeutralRepairStatus(Header);
        Alloc.Status := Alloc.Status::"Reallocation Needed";
        Alloc.Modify();
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Second."No.", '', '', '');
        Assert.AreEqual('Canceled', Data.TextValue(Response, 'previousStatus'), 'Reallocation Needed becomes a canceled history entry.');
        Alloc.Get(Alloc."Entry No.");
        Alloc."Service Started" := true;
        Alloc.Status := Alloc.Status::Active;
        Alloc.Modify();
        Data.CreateResourceFor(Header."Customer No.", Second);
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Second."No.", '', '', '');
        Restore(Zones, Skills);
        Assert.AreEqual('Finished', Data.TextValue(Response, 'previousStatus'), 'Started service finishes the previous entry.');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual(Alloc.Status::Active, Alloc.Status, 'The moved entry stays active.');
    end;

    [Test]
    procedure Scenario_InitialRepairStatus_BecomesReferred()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        ItemLine: Record "Service Item Line";
        Initial: Record "Repair Status";
        Referred: Record "Repair Status";
        First: Record Resource;
        Second: Record Resource;
        Service: Codeunit "Library - Service";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        Activate(Header, Alloc, First, Zones, Skills);
        Data.CreateResourceFor(Header."Customer No.", Second);
        Service.CreateRepairStatus(Initial);
        Initial.Initial := true;
        Initial.Modify();
        Service.CreateRepairStatus(Referred);
        Referred.Referred := true;
        Referred.Modify();
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        ItemLine."Repair Status Code" := Initial.Code;
        ItemLine.Modify();
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Second."No.", '', '', '');
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Initial line can be moved.');
        ItemLine.FindFirst();
        Referred.Get(ItemLine."Repair Status Code");
        Assert.IsTrue(Referred.Referred, 'Repair status moved to a referred status.');
    end;

    [Test]
    procedure Scenario_OneResource_UsesBusinessCentralText()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Extra: Record "Service Order Allocation";
        First: Record Resource;
        Second: Record Resource;
        Third: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        Activate(Header, Alloc, First, Zones, Skills);
        Data.CreateResourceFor(Header."Customer No.", Second);
        Data.CreateResourceFor(Header."Customer No.", Third);
        Extra.Init();
        Extra."Document Type" := Header."Document Type";
        Extra."Document No." := Header."No.";
        Extra."Service Item Line No." := Alloc."Service Item Line No.";
        Extra."Service Item No." := Alloc."Service Item No.";
        Extra."Allocation Date" := WorkDate();
        Extra."Resource No." := Second."No.";
        Extra."Allocated Hours" := 1;
        Extra.Status := Extra.Status::Active;
        Extra.SetHideDialog(true);
        Extra.Insert(true);
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Third."No.", '', '', '');
        Restore(Zones, Skills);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('Only one'), 'HideDialog still enforces one resource.');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual(First."No.", Alloc."Resource No.", 'The selected entry was not moved.');
    end;

    [Test]
    procedure Scenario_EntryNo_SelectsAmongSeveralOpenEntries()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Extra: Record "Service Order Allocation";
        First: Record Resource;
        Second: Record Resource;
        Third: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        Activate(Header, Alloc, First, Zones, Skills);
        Data.CreateResourceFor(Header."Customer No.", Second);
        Data.CreateResourceFor(Header."Customer No.", Third);
        Extra.Init();
        Extra."Document Type" := Header."Document Type";
        Extra."Document No." := Header."No.";
        Extra."Service Item Line No." := Alloc."Service Item Line No.";
        Extra."Service Item No." := Alloc."Service Item No.";
        Extra.Status := Extra.Status::"Reallocation Needed";
        Extra.SetHideDialog(true);
        Extra.Insert(true);
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Third."No.", '', '', '');
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'entryNo is not ambiguous.');
        Assert.AreEqual(Format(Alloc."Entry No."), Data.TextValue(Response, 'entryNo'), 'The requested entry was moved.');
    end;

    [Test]
    procedure Scenario_InvalidTime_RollsBackInsertedHistory()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        First: Record Resource;
        Second: Record Resource;
        History: Record "Service Order Allocation";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        Activate(Header, Alloc, First, Zones, Skills);
        Data.CreateResourceFor(Header."Customer No.", Second);
        SetNeutralRepairStatus(Header);
        Commit();
        Response := Move(Header."No.", Alloc."Entry No.", Second."No.", '', '10:00', '09:00');
        Restore(Zones, Skills);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual(First."No.", Alloc."Resource No.", 'Failed reallocation restored the resource.');
        History.SetRange("Document Type", Header."Document Type");
        History.SetRange("Document No.", Header."No.");
        Assert.AreEqual(1, History.Count(), 'The inserted history entry was rolled back.');
    end;

    local procedure Activate(var Header: Record "Service Header"; var Alloc: Record "Service Order Allocation"; var Resource: Record Resource; var Zones: Option "Code Shown","Warning Displayed","Not Used"; var Skills: Option "Code Shown","Warning Displayed","Not Used")
    var
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.CreateResourceFor(Header."Customer No.", Resource);
        Data.SilenceServiceRules(Zones, Skills);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", BasePayload(Header."No.", Resource."No."), '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Fixture allocation.');
        Data.FindAllocation(Header, Alloc);
    end;

    local procedure Move(DocumentNo: Code[20]; EntryNo: Integer; ResourceNo: Code[20]; Reason: Code[10]; StartTime: Text; FinishTime: Text): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('documentNo', DocumentNo);
        Request.Add('entryNo', EntryNo);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('allocatedHours', 2);
        if Reason <> '' then
            Request.Add('reasonCode', Reason);
        if StartTime <> '' then
            Request.Add('startingTime', StartTime);
        if FinishTime <> '' then
            Request.Add('finishingTime', FinishTime);
        exit(Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false));
    end;

    local procedure BasePayload(DocumentNo: Code[20]; ResourceNo: Code[20]): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('documentNo', DocumentNo);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('allocatedHours', 2);
        exit(Request);
    end;

    local procedure CreateReason(var Reason: Record "Reason Code")
    begin
        Reason.Init();
        Reason.Code := CopyStr('R' + DelChr(Format(CreateGuid(), 0, 4), '=', '-{}'), 1, MaxStrLen(Reason.Code));
        Reason.Insert();
    end;

    local procedure SetNeutralRepairStatus(Header: Record "Service Header")
    var
        ItemLine: Record "Service Item Line";
        RepairStatus: Record "Repair Status";
        Service: Codeunit "Library - Service";
    begin
        Service.CreateRepairStatus(RepairStatus);
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        ItemLine."Repair Status Code" := RepairStatus.Code;
        ItemLine.Modify();
    end;

    local procedure Restore(Zones: Option "Code Shown","Warning Displayed","Not Used"; Skills: Option "Code Shown","Warning Displayed","Not Used")
    begin
        Data.RestoreServiceRules(Zones, Skills);
        Commit();
    end;
}
