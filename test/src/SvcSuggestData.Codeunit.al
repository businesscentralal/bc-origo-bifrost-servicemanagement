namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Resources;
using Microsoft.Service.Setup;
using Microsoft.Service.Test;

/// <summary>Builds an owned dispatch fixture: one service order line that needs a skill in a zone, and four resources in an owned group.</summary>
codeunit 97783 "Svc Suggest Data ori"
{
    var
        Data: Codeunit "Svc Test Data ori";

    /// <summary>
    /// Creates the order and resources. Capacity is 8 hours per day on FirstDay and FirstDay + 1.
    /// Qualified = skilled, Remote = skilled but outside the zone, Busy = skilled, in zone, 3 hours allocated, Unskilled = in zone without the skill.
    /// </summary>
    procedure Create(var Header: Record "Service Header"; var ItemLine: Record "Service Item Line"; var GroupNo: Code[20]; var Qualified: Code[20]; var Remote: Code[20]; var Busy: Code[20]; var Unskilled: Code[20]; FirstDay: Date)
    var
        Customer: Record Customer;
        ResourceGroup: Record "Resource Group";
        SkillCode: Record "Skill Code";
        Zone: Record "Service Zone";
        RequiredSkill: Record "Resource Skill";
        Resources: Codeunit "Library - Resource";
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        ItemLine.FindFirst();
        Zone.Init();
        Zone.Code := CopyStr(NewCode(10), 1, MaxStrLen(Zone.Code));
        Zone.Description := 'Dispatch test zone';
        Zone.Insert();
        Header."Service Zone Code" := Zone.Code;
        Header.Modify();
        SkillCode.Init();
        SkillCode.Code := CopyStr(NewCode(10), 1, MaxStrLen(SkillCode.Code));
        SkillCode.Description := 'Dispatch test skill';
        SkillCode.Insert();
        RequiredSkill.Init();
        RequiredSkill.Type := RequiredSkill.Type::"Service Item";
        RequiredSkill."No." := ItemLine."Service Item No.";
        RequiredSkill."Skill Code" := SkillCode.Code;
        RequiredSkill.Insert();
        Resources.CreateResourceGroup(ResourceGroup);
        GroupNo := ResourceGroup."No.";
        Customer.Get(Header."Customer No.");
        Qualified := NewResource(Customer, GroupNo, SkillCode.Code, Zone.Code, FirstDay);
        Remote := NewResource(Customer, GroupNo, SkillCode.Code, '', FirstDay);
        Busy := NewResource(Customer, GroupNo, SkillCode.Code, Zone.Code, FirstDay);
        Unskilled := NewResource(Customer, GroupNo, '', Zone.Code, FirstDay);
        Allocate(Header, ItemLine, Busy, FirstDay, 3);
    end;

    /// <summary>Sets both service setup options and returns the previous ones.</summary>
    procedure SetOptions(Skills: Option "Code Shown","Warning Displayed","Not Used"; Zones: Option "Code Shown","Warning Displayed","Not Used"; var OldSkills: Option "Code Shown","Warning Displayed","Not Used"; var OldZones: Option "Code Shown","Warning Displayed","Not Used")
    var
        Setup: Record "Service Mgt. Setup";
    begin
        Setup.Get();
        OldSkills := Setup."Resource Skills Option";
        OldZones := Setup."Service Zones Option";
        Setup."Resource Skills Option" := Skills;
        Setup."Service Zones Option" := Zones;
        Setup.Modify();
    end;

    /// <summary>Restores the options returned by SetOptions.</summary>
    procedure RestoreOptions(OldSkills: Option "Code Shown","Warning Displayed","Not Used"; OldZones: Option "Code Shown","Warning Displayed","Not Used")
    var
        Setup: Record "Service Mgt. Setup";
    begin
        Setup.Get();
        Setup."Resource Skills Option" := OldSkills;
        Setup."Service Zones Option" := OldZones;
        Setup.Modify();
    end;

    /// <summary>Adds an active allocation for a resource.</summary>
    procedure Allocate(Header: Record "Service Header"; ItemLine: Record "Service Item Line"; ResourceNo: Code[20]; AllocationDate: Date; Hours: Decimal)
    var
        Alloc: Record "Service Order Allocation";
        EntryNo: Integer;
    begin
        if Alloc.FindLast() then
            EntryNo := Alloc."Entry No.";
        Alloc.Init();
        Alloc."Entry No." := EntryNo + 1;
        Alloc."Document Type" := Header."Document Type";
        Alloc."Document No." := Header."No.";
        Alloc."Service Item Line No." := ItemLine."Line No.";
        Alloc."Service Item No." := ItemLine."Service Item No.";
        Alloc.Status := Alloc.Status::Active;
        Alloc."Resource No." := ResourceNo;
        Alloc."Allocation Date" := AllocationDate;
        Alloc."Allocated Hours" := Hours;
        Alloc.Insert();
    end;

    local procedure NewResource(Customer: Record Customer; GroupNo: Code[20]; Skill: Code[10]; ZoneCode: Code[10]; FirstDay: Date): Code[20]
    var
        Resource: Record Resource;
        ResourceSkill: Record "Resource Skill";
        ResourceZone: Record "Resource Service Zone";
        Resources: Codeunit "Library - Resource";
    begin
        Resources.CreateResource(Resource, Customer."VAT Bus. Posting Group");
        Resource."Resource Group No." := GroupNo;
        Resource.Modify();
        if Skill <> '' then begin
            ResourceSkill.Init();
            ResourceSkill.Type := ResourceSkill.Type::Resource;
            ResourceSkill."No." := Resource."No.";
            ResourceSkill."Skill Code" := Skill;
            ResourceSkill.Insert();
        end;
        if ZoneCode <> '' then begin
            ResourceZone.Init();
            ResourceZone."Resource No." := Resource."No.";
            ResourceZone."Service Zone Code" := ZoneCode;
            ResourceZone."Starting Date" := FirstDay;
            ResourceZone.Insert();
        end;
        AddCapacity(Resource."No.", FirstDay, 8);
        AddCapacity(Resource."No.", FirstDay + 1, 8);
        exit(Resource."No.");
    end;

    local procedure AddCapacity(ResourceNo: Code[20]; Day: Date; Hours: Decimal)
    var
        Entry: Record "Res. Capacity Entry";
        EntryNo: Integer;
    begin
        if Entry.FindLast() then
            EntryNo := Entry."Entry No.";
        Entry.Init();
        Entry."Entry No." := EntryNo + 1;
        Entry."Resource No." := ResourceNo;
        Entry.Date := Day;
        Entry.Capacity := Hours;
        Entry.Insert();
    end;

    local procedure NewCode(Length: Integer): Code[20]
    begin
        exit(CopyStr(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, Length), 1, 20));
    end;
}
