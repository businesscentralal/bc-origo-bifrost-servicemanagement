namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Maintenance;
using Microsoft.Service.Resources;
using Microsoft.Service.Setup;
using Microsoft.Service.Test;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Dispatcher acceptance for allocating a nonactive service order entry.</summary>
codeunit 97725 "Svc Allocation Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_Allocate_ByDocumentNo_ActivatesEntry()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Resource: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
        Token: JsonToken;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 2, WorkDate(), '', false);
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Allocated.');
        Assert.AreEqual(Header."No.", Data.TextValue(Response, 'documentNo'), 'Order.');
        Assert.AreEqual('Active', Data.TextValue(Response, 'allocationStatus'), 'Active.');
        Assert.AreEqual(Resource."No.", Data.TextValue(Response, 'resourceNo'), 'Resource.');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Data.TextValue(Response, 'allocationDate'), 'Date.');
        Assert.AreEqual('false', Data.TextValue(Response, 'reallocated'), 'First allocation.');
        Response.Get('allocatedHours', Token);
        Assert.AreEqual(2, Token.AsValue().AsDecimal(), 'Hours.');
        Data.FindAllocation(Header, Alloc);
        Assert.AreEqual(Alloc.Status::Active, Alloc.Status, 'Persisted status.');
        Assert.AreEqual(Resource."No.", Alloc."Resource No.", 'Persisted resource.');
        Assert.AreEqual(2, Alloc."Allocated Hours", 'Persisted hours.');
    end;

    [Test]
    procedure Scenario_Allocate_BySystemIdSubjectAndEntryNo()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Resource: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Request: JsonObject;
        Response: JsonObject;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Data.FindAllocation(Header, Alloc);
        Commit();
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Request.Add('resourceNo', Resource."No.");
        Request.Add('allocatedHours', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'systemId.');
        ResetNonactive(Alloc);
        Clear(Request);
        Request.Add('entryNo', Alloc."Entry No.");
        Request.Add('resourceNo', Resource."No.");
        Request.Add('allocatedHours', 1);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'entryNo.');
        ResetNonactive(Alloc);
        Restore(Zones, Skills);
        Clear(Request);
        Request.Add('resourceNo', Resource."No.");
        Request.Add('allocatedHours', 1);
        Data.SilenceServiceRules(Zones, Skills);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, Header."No.", 1033, false);
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'subject.');
    end;

    [Test]
    procedure Scenario_Allocate_GroupOnly_AndTimes()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Group: Record "Resource Group";
        Resources: Codeunit "Library - Resource";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.SilenceServiceRules(Zones, Skills);
        Resources.CreateResourceGroup(Group);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceGroupNo', Group."No.");
        Request.Add('allocatedHours', 3);
        Request.Add('startingTime', '09:00');
        Request.Add('finishingTime', '12:00');
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Group allocation.');
        Assert.AreEqual(Group."No.", Data.TextValue(Response, 'resourceGroupNo'), 'Group.');
        Data.FindAllocation(Header, Alloc);
        Assert.AreEqual(Group."No.", Alloc."Resource Group No.", 'Persisted group.');
        Assert.AreEqual(090000T, Alloc."Starting Time", 'Start.');
        Assert.AreEqual(120000T, Alloc."Finishing Time", 'Finish.');
    end;

    [Test]
    procedure Scenario_Allocate_DefaultAndPastDate()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Resource: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Request: JsonObject;
        Response: JsonObject;
        Past: Date;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Past := CalcDate('<-2D>', WorkDate());
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', Resource."No.");
        Request.Add('allocatedHours', 1);
        Request.Add('allocationDate', Format(Past, 0, 9));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Past date is assigned, not validated.');
        Assert.AreEqual(Format(Past, 0, 9), Data.TextValue(Response, 'allocationDate'), 'Past date returned.');
        Data.FindAllocation(Header, Alloc);
        Assert.AreEqual(Past, Alloc."Allocation Date", 'Past date stored.');
    end;

    [Test]
    procedure Scenario_Validation_MissingInvalidAndUnknown()
    var
        Header: Record "Service Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'MissingParameter');
        Request.Add('documentNo', Header."No.");
        Request.Add('allocatedHours', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'MissingParameter');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('resourceNo'), 'Names a resource.');
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', 'X-NO-RES');
        Request.Add('allocatedHours', 0);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'MultipleErrors');
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', 'X-NO-RES');
        Request.Add('allocatedHours', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'RecordNotFound');
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', 'X');
        Request.Add('allocatedHours', '2');
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Clear(Request);
        Request.Add('systemId', 'not-a-guid');
        Request.Add('allocatedHours', 1);
        Request.Add('resourceNo', 'X');
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameterFormat');
        Request.Add('extra', 'x');
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'UnknownParameter');
        Assert.AreEqual('extra', Data.TextValue(Response, 'parameter'), 'Unknown key stays outside MultipleErrors.');
    end;

    [Test]
    procedure Scenario_OrdersOnly_AndSeveralLines()
    var
        Header: Record "Service Header";
        Quote: Record "Service Header";
        Item: Record "Service Item";
        ItemLine: Record "Service Item Line";
        Service: Codeunit "Library - Service";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Data.CreateDocument(Quote, Quote."Document Type"::Quote);
        Request.Add('systemId', Format(Quote.SystemId, 0, 4));
        Request.Add('resourceNo', 'X');
        Request.Add('allocatedHours', 1);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('not an Order'), 'Names the order type.');
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Service.CreateServiceItem(Item, Header."Customer No.");
        Service.CreateServiceItemLine(ItemLine, Header, Item."No.");
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', 'X');
        Request.Add('allocatedHours', 1);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, false);
        Data.AssertRefusal(Response, 'AmbiguousRecord');
        Assert.AreEqual('Service order ' + Header."No." + ' has more than one service item line.', Data.TextValue(Response, 'error'), 'Several lines.');
        Assert.AreEqual('Send serviceItemLineNo.', Data.TextValue(Response, 'nextStep'), 'Line next step.');
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', 'X');
        Request.Add('allocatedHours', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1039, false);
        Data.AssertRefusal(Response, 'AmbiguousRecord');
        Assert.AreEqual('Þjónustupöntun ' + Header."No." + ' er með fleiri en eina þjónustuvörulínu.', Data.TextValue(Response, 'error'), 'Icelandic several lines.');
        Assert.AreEqual('Sendu serviceItemLineNo.', Data.TextValue(Response, 'nextStep'), 'Icelandic line next step.');
    end;

    [Test]
    procedure Scenario_NoOpenEntry_AndOutsideZone()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Resource: Record Resource;
        Zone: Record "Service Zone";
        Membership: Record "Resource Service Zone";
        InZone: Record Resource;
        Setup: Record "Service Mgt. Setup";
        Service: Codeunit "Library - Service";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Request: JsonObject;
        Response: JsonObject;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Data.FindAllocation(Header, Alloc);
        Alloc.Status := Alloc.Status::Canceled;
        Alloc.Modify();
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('No open allocation'), 'No open entry.');
        Alloc.Status := Alloc.Status::Nonactive;
        Alloc.Modify();
        Service.CreateServiceZone(Zone);
        Header.Validate("Service Zone Code", Zone.Code);
        Header.Modify(true);
        Setup.Get();
        Setup."Service Zones Option" := Setup."Service Zones Option"::"Warning Displayed";
        Setup.Modify();
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual('Resource ' + Resource."No." + ' does not work in service zone ' + Zone.Code + '. Nothing was changed.', Data.TextValue(Response, 'error'), 'Zone refusal.');
        Assert.AreEqual('Choose a resource that works in the zone, or send acceptOutsideServiceZone = true.', Data.TextValue(Response, 'nextStep'), 'Zone next step.');
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Acknowledged outside zone.');
        Data.CreateResourceFor(Header."Customer No.", InZone);
        Membership.Init();
        Membership.Validate("Resource No.", InZone."No.");
        Membership.Validate("Service Zone Code", Zone.Code);
        Membership.Insert(true);
        Data.FindAllocation(Header, Alloc);
        Alloc.Status := Alloc.Status::Nonactive;
        Alloc."Resource No." := '';
        Alloc."Resource Group No." := '';
        Alloc."Allocation Date" := 0D;
        Alloc.Modify();
        Commit();
        Clear(Request);
        Request.Add('documentNo', Header."No.");
        Request.Add('resourceNo', InZone."No.");
        Request.Add('allocatedHours', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1039, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Resource in the zone.');
        Alloc.Get(Alloc."Entry No.");
        Alloc.Status := Alloc.Status::Nonactive;
        Alloc."Resource No." := '';
        Alloc."Resource Group No." := '';
        Alloc."Allocation Date" := 0D;
        Alloc.Modify();
        Setup.Get();
        Setup."Service Zones Option" := Setup."Service Zones Option"::"Code Shown";
        Setup.Modify();
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', false);
        Restore(Zones, Skills);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Code Shown does not require the flag.');
    end;

    [Test]
    procedure Scenario_ZoneText_Icelandic()
    var
        Header: Record "Service Header";
        Resource: Record Resource;
        Zone: Record "Service Zone";
        Setup: Record "Service Mgt. Setup";
        Service: Codeunit "Library - Service";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Service.CreateServiceZone(Zone);
        Header.Validate("Service Zone Code", Zone.Code);
        Header.Modify(true);
        Setup.Get();
        Setup."Service Zones Option" := Setup."Service Zones Option"::"Warning Displayed";
        Setup.Modify();
        Commit();
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Payload(Header."No.", Resource."No.", 1, false), '', 1039, false);
        Restore(Zones, Skills);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual('Forði ' + Resource."No." + ' vinnur ekki á þjónustusvæði ' + Zone.Code + '. Engu var breytt.', Data.TextValue(Response, 'error'), 'Icelandic zone.');
        Assert.AreEqual('Veldu forða sem vinnur á svæðinu eða sendu acceptOutsideServiceZone = true.', Data.TextValue(Response, 'nextStep'), 'Icelandic zone next step.');
    end;

    [Test]
    procedure Scenario_FinishedOrderAndLine_Precondition()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        RepairStatus: Record "Repair Status";
        Resource: Record Resource;
        Service: Codeunit "Library - Service";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Header.Status := Header.Status::Finished;
        Header.Modify();
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('finished'), 'Finished order.');
        Header.Status := Header.Status::Pending;
        Header.Modify();
        Service.CreateRepairStatus(RepairStatus);
        RepairStatus.Finished := true;
        RepairStatus.Modify();
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        ItemLine."Repair Status Code" := RepairStatus.Code;
        ItemLine.Modify();
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', false);
        Restore(Zones, Skills);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('finished repair status'), 'Finished line.');
    end;

    [Test]
    procedure Scenario_SkillWarning_IsBusinessCentralError()
    var
        Header: Record "Service Header";
        ItemLine: Record "Service Item Line";
        Resource: Record Resource;
        Skill: Record "Skill Code";
        ResourceSkill: Record "Resource Skill";
        Setup: Record "Service Mgt. Setup";
        Resources: Codeunit "Library - Resource";
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Response: JsonObject;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Resources.CreateSkillCode(Skill);
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        Resources.CreateResourceSkill(ResourceSkill, ResourceSkill.Type::"Service Item", ItemLine."Service Item No.", Skill.Code);
        Setup.Get();
        Setup."Resource Skills Option" := Setup."Resource Skills Option"::"Warning Displayed";
        Setup.Modify();
        Commit();
        Response := Allocate(Header."No.", Resource."No.", 1, WorkDate(), '', false);
        Restore(Zones, Skills);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('not qualified'), 'Skill warning text.');
    end;

    [Test]
    procedure Scenario_OmitCommit_CallerRollback()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Resource: Record Resource;
        Zones: Option "Code Shown","Warning Displayed","Not Used";
        Skills: Option "Code Shown","Warning Displayed","Not Used";
        Request: JsonObject;
    begin
        PrepareOrder(Header, Resource, Zones, Skills);
        Data.FindAllocation(Header, Alloc);
        Request := Payload(Header."No.", Resource."No.", 2, false);
        Commit();
        asserterror AllocateAndAbort(Request);
        Restore(Zones, Skills);
        Assert.ExpectedError('X caller aborted allocation');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual(Alloc.Status::Nonactive, Alloc.Status, 'Omit Commit kept the caller transaction.');
        Assert.AreEqual('', Alloc."Resource No.", 'Resource was not committed.');
    end;

    local procedure PrepareOrder(var Header: Record "Service Header"; var Resource: Record Resource; var Zones: Option "Code Shown","Warning Displayed","Not Used"; var Skills: Option "Code Shown","Warning Displayed","Not Used")
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.CreateResourceFor(Header."Customer No.", Resource);
        Data.SilenceServiceRules(Zones, Skills);
    end;

    local procedure Restore(Zones: Option "Code Shown","Warning Displayed","Not Used"; Skills: Option "Code Shown","Warning Displayed","Not Used")
    begin
        Data.RestoreServiceRules(Zones, Skills);
        Commit();
    end;

    local procedure Allocate(DocumentNo: Code[20]; ResourceNo: Code[20]; Hours: Decimal; AllocDate: Date; Subject: Text; AcceptOutside: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('documentNo', DocumentNo);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('allocatedHours', Hours);
        Request.Add('allocationDate', Format(AllocDate, 0, 9));
        if AcceptOutside then
            Request.Add('acceptOutsideServiceZone', true);
        exit(Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, Subject, 1033, false));
    end;

    local procedure Payload(DocumentNo: Code[20]; ResourceNo: Code[20]; Hours: Decimal; AcceptOutside: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('documentNo', DocumentNo);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('allocatedHours', Hours);
        if AcceptOutside then
            Request.Add('acceptOutsideServiceZone', true);
        exit(Request);
    end;

    local procedure ResetNonactive(var Alloc: Record "Service Order Allocation")
    begin
        Alloc.Get(Alloc."Entry No.");
        Alloc.Status := Alloc.Status::Nonactive;
        Alloc."Resource No." := '';
        Alloc."Resource Group No." := '';
        Alloc."Allocation Date" := 0D;
        Alloc."Allocated Hours" := 0;
        Alloc.Modify();
    end;

    local procedure AllocateAndAbort(Request: JsonObject)
    var
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Service.Allocation.Allocate", Request, '', 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Allocation succeeded before rollback.');
        Error('X caller aborted allocation');
    end;
}
