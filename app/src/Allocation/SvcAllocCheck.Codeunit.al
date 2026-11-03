namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Foundation.AuditCodes;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.BaseApp;
using Microsoft.Service.Document;
using Microsoft.Service.Maintenance;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>Validates a service allocation request and applies it through standard Business Central.</summary>
codeunit 10076063 "Svc Alloc Check ori"
{
    Access = Internal;

    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        ResourceNo: Code[20];
        ResourceGroupNo: Code[20];
        ReasonCode: Code[10];
        AllocationDate: Date;
        StartTime: Time;
        FinishTime: Time;
        Hours: Decimal;
        RequestedEntryNo: Integer;
        RequestedLineNo: Integer;
        DocumentAttempted: Boolean;
        SystemAttempted: Boolean;
        EntrySent: Boolean;
        LineSent: Boolean;
        ResourceSent: Boolean;
        GroupSent: Boolean;
        ReasonSent: Boolean;
        HasStart: Boolean;
        HasFinish: Boolean;
        AcceptOutside: Boolean;
        Reallocate: Boolean;
        NothingLbl: Label 'Nothing was changed.', Comment = 'is-IS=Engu var breytt.';
        CorrectLbl: Label 'Send the value in the format documented by describe_message_type.', Comment = 'is-IS=Sendu gildið á sniðinu sem describe_message_type lýsir.';
        MissingIdentLbl: Label 'Send documentNo, systemId, entryNo or a plain subject.', Comment = 'is-IS=Sendu documentNo, systemId, entryNo eða númer skjalsins í subject.';
        StringLbl: Label '%1 must be a nonempty JSON string of at most %2 characters.', Comment = '%1 = parameter, %2 = maximum, is-IS=%1 verður að vera JSON-strengur sem er ekki tómur og er að hámarki %2 stafir.';
        GuidLbl: Label 'systemId must be a nonempty GUID.', Comment = 'is-IS=systemId verður að vera gilt GUID sem er ekki tómt.';
        IntegerLbl: Label '%1 must be a positive whole number.', Comment = '%1 = parameter, is-IS=%1 verður að vera jákvæð heiltala.';
        DateLbl: Label 'allocationDate must be a yyyy-mm-dd date.', Comment = 'is-IS=allocationDate verður að vera dagsetning á sniðinu yyyy-mm-dd.';
        TimeLbl: Label '%1 must be a time as hh:mm.', Comment = '%1 = parameter, is-IS=%1 verður að vera tími á sniðinu hh:mm.';
        BooleanLbl: Label 'acceptOutsideServiceZone must be a JSON boolean.', Comment = 'is-IS=acceptOutsideServiceZone verður að vera JSON boolean.';
        HoursMissingLbl: Label 'Send allocatedHours.', Comment = 'is-IS=Sendu allocatedHours.';
        HoursLbl: Label 'allocatedHours must be greater than 0.', Comment = 'is-IS=allocatedHours verður að vera stærra en 0.';
        HoursNextLbl: Label 'Send allocatedHours greater than 0.', Comment = 'is-IS=Sendu allocatedHours sem er stærra en 0.';
        NoResourceLbl: Label 'Send resourceNo or resourceGroupNo.', Comment = 'is-IS=Sendu resourceNo eða resourceGroupNo.';
        EntryMissingLbl: Label 'Allocation entry %1 was not found.', Comment = '%1 = entry number, is-IS=Úthlutunarfærsla %1 fannst ekki.';
        ReadAllocLbl: Label 'Read the allocations with Data.Records.Get (table Service Order Allocation).', Comment = 'is-IS=Lestu úthlutanirnar með Data.Records.Get (tafla Service Order Allocation).';
        ResourceMissingLbl: Label 'Resource %1 was not found.', Comment = '%1 = resource number, is-IS=Forði %1 fannst ekki.';
        ReadResourceLbl: Label 'Read resources with Data.Records.Get (table Resource).', Comment = 'is-IS=Lestu forða með Data.Records.Get (tafla Resource).';
        GroupMissingLbl: Label 'Resource group %1 was not found.', Comment = '%1 = resource group, is-IS=Forðaflokkur %1 fannst ekki.';
        ReadGroupLbl: Label 'Read resource groups with Data.Records.Get (table Resource Group).', Comment = 'is-IS=Lestu forðaflokka með Data.Records.Get (tafla Resource Group).';
        ReasonMissingLbl: Label 'Reason code %1 was not found.', Comment = '%1 = reason code, is-IS=Ástæðukóði %1 fannst ekki.';
        ReadReasonLbl: Label 'Read reason codes with Data.Records.Get (table Reason Code).', Comment = 'is-IS=Lestu ástæðukóða með Data.Records.Get (tafla Reason Code).';
        OrderTypeLbl: Label 'Service document %1 is not an Order (actual type: %2).', Comment = '%1 = number, %2 = actual type, is-IS=Þjónustuskjal %1 er ekki pöntun (raunveruleg gerð: %2).';
        OrderTypeNextLbl: Label 'Send the No. or SystemId of a service order.', Comment = 'is-IS=Sendu númer eða SystemId þjónustupöntunar.';
        ConflictLbl: Label 'The identifiers do not identify the same service document.', Comment = 'is-IS=Auðkennin vísa ekki á sama þjónustuskjalið.';
        ConflictNextLbl: Label 'Send identifiers belonging to the same service document.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sama þjónustuskjalinu.';
        LineConflictLbl: Label 'entryNo and serviceItemLineNo do not identify the same service item line.', Comment = 'is-IS=entryNo og serviceItemLineNo vísa ekki á sömu þjónustuvörulínuna.';
        LineConflictNextLbl: Label 'Send identifiers belonging to the same allocation.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sömu úthlutuninni.';
        LineMissingLbl: Label 'Service item line %1 was not found on service order %2.', Comment = '%1 = line number, %2 = order number, is-IS=Þjónustuvörulína %1 fannst ekki á þjónustupöntun %2.';
        LineNextLbl: Label 'Send the Line No. of a service item line on the order.', Comment = 'is-IS=Sendu línunúmer þjónustuvörulínu á pöntuninni.';
        NoLineLbl: Label 'Service order %1 has no service item line.', Comment = '%1 = order number, is-IS=Þjónustupöntun %1 er ekki með þjónustuvörulínu.';
        SeveralLinesLbl: Label 'Service order %1 has more than one service item line.', Comment = '%1 = order number, is-IS=Þjónustupöntun %1 er með fleiri en eina þjónustuvörulínu.';
        SeveralLinesNextLbl: Label 'Send serviceItemLineNo.', Comment = 'is-IS=Sendu serviceItemLineNo.';
        SeveralOpenLbl: Label 'Service item line %1 of service order %2 has more than one open allocation.', Comment = '%1 = line number, %2 = order number, is-IS=Þjónustuvörulína %1 í þjónustupöntun %2 er með fleiri en eina opna úthlutun.';
        SeveralOpenNextLbl: Label 'Send entryNo.', Comment = 'is-IS=Sendu entryNo.';
        NoOpenLbl: Label 'No open allocation was found for service item line %1 of service order %2.', Comment = '%1 = line number, %2 = order number, is-IS=Engin opin úthlutun fannst fyrir þjónustuvörulínu %1 í þjónustupöntun %2.';
        ZoneLbl: Label 'Resource %1 does not work in service zone %2. Nothing was changed.', Comment = '%1 = resource number, %2 = service zone, is-IS=Forði %1 vinnur ekki á þjónustusvæði %2. Engu var breytt.';
        ZoneNextLbl: Label 'Choose a resource that works in the zone, or send acceptOutsideServiceZone = true.', Comment = 'is-IS=Veldu forða sem vinnur á svæðinu eða sendu acceptOutsideServiceZone = true.';
        FinishedOrderLbl: Label 'Service order %1 is finished. Nothing was changed.', Comment = '%1 = order number, is-IS=Þjónustupöntun %1 er lokið. Engu var breytt.';
        FinishedLineLbl: Label 'Service item line %1 of service order %2 has a finished repair status. Nothing was changed.', Comment = '%1 = line number, %2 = order number, is-IS=Þjónustuvörulína %1 í þjónustupöntun %2 er með lokastöðu viðgerðar. Engu var breytt.';
        FinishedNextLbl: Label 'Correct the finished service order or service item line and try again.', Comment = 'is-IS=Leiðréttu þjónustupöntunina eða þjónustuvörulínuna sem er lokið og reyndu aftur.';
        OnlyOneLbl: Label 'Only one %1 can be allocated to a %2.', Comment = '%1 = resource or resource group, %2 = service item line, is-IS=Aðeins einum %1 er hægt að úthluta á %2.';
        SubjectLbl: Label 'subject must be a service order number of at most %1 characters.', Comment = '%1 = maximum, is-IS=subject verður að vera númer þjónustupöntunar sem er að hámarki %1 stafir.';

    /// <summary>Reads every declared parameter, resolves the open allocation and refuses anything that must not be written.</summary>
    internal procedure Load(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
    begin
        ClearState();
        Request := Argument.GetRequestJson();
        ReadParameters(Request, Argument);
        CollectReferenceErrors(Argument);
        if Argument.HasCollectedErrors() then begin
            Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, NothingLbl);
            exit(false);
        end;
        if not ResolveDocument(Argument) then
            exit(false);
        if not ResolveLine(Argument) then
            exit(false);
        if not ResolveAllocation(Argument) then
            exit(false);
        if not EnsureZone(Argument) then
            exit(false);
        if not EnsureWritable(Argument) then
            exit(false);
        exit(true);
    end;

    /// <summary>Allocates a nonactive entry or reallocates an active one inside the caller's run boundary.</summary>
    internal procedure Apply(var Argument: Record "Message Argument ori")
    var
        OldResource: Code[20];
        OldGroup: Code[20];
        EntryNo: Integer;
    begin
        EntryNo := Alloc."Entry No.";
        Alloc.ReadIsolation := IsolationLevel::UpdLock;
        Alloc.Get(EntryNo);
        OldResource := Alloc."Resource No.";
        OldGroup := Alloc."Resource Group No.";
        Reallocate := (Alloc.Status = Alloc.Status::Active) or (Alloc.Status = Alloc.Status::"Reallocation Needed");
        if Reallocate then
            ReallocateEntry()
        else
            AllocateNonactive();
        WriteSuccess(Argument, OldResource, OldGroup);
    end;

    /// <summary>Reports whether the resolved order or service item line is finished, without writing a response.</summary>
    internal procedure IsFinishedPrecondition(var Argument: Record "Message Argument ori"): Boolean
    var
        Probe: Codeunit "Svc Alloc Check ori";
    begin
        if not Probe.TryBindFinished(Argument) then
            exit(false);
        exit(Probe.BoundTargetIsFinished());
    end;

    /// <summary>Binds the request quietly so a rolled-back Business Central failure can be remapped.</summary>
    internal procedure TryBindFinished(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
    begin
        ClearState();
        Request := Argument.GetRequestJson();
        ReadParameters(Request, Argument);
        if Argument.HasCollectedErrors() then
            exit(false);
        if not ResolveDocument(Argument) then
            exit(false);
        if not ResolveLine(Argument) then
            exit(false);
        if not ResolveAllocation(Argument) then
            exit(false);
        exit(true);
    end;

    /// <summary>Returns whether the bound order or repair status is finished.</summary>
    internal procedure BoundTargetIsFinished(): Boolean
    begin
        exit(OrderIsFinished() or LineIsFinished());
    end;

    local procedure AllocateNonactive()
    var
        AllocMgt: Codeunit ServAllocationManagement;
        GroupToPass: Code[20];
    begin
        if GroupSent then
            GroupToPass := ResourceGroupNo;
        AllocMgt.AllocateDate(Header."Document Type".AsInteger(), Header."No.", Alloc."Entry No.", ResourceNo, GroupToPass, AllocationDate, Hours);
        Alloc.Get(Alloc."Entry No.");
        ApplyOptionalFields();
    end;

    local procedure ReallocateEntry()
    var
        AllocMgt: Codeunit ServAllocationManagement;
    begin
        AllocMgt.CheckServiceItemLineFinished(Header, Alloc."Service Item Line No.");
        AssertOneResource();
        Alloc.SetHideDialog(true);
        Alloc."Allocation Date" := AllocationDate;
        if ResourceSent then
            Alloc.Validate("Resource No.", ResourceNo);
        if GroupSent then
            Alloc.Validate("Resource Group No.", ResourceGroupNo);
        Alloc.Validate("Allocated Hours", Hours);
        if ReasonSent then
            Alloc.Validate("Reason Code", ReasonCode);
        if HasStart then
            Alloc.Validate("Starting Time", StartTime);
        if HasFinish then
            Alloc.Validate("Finishing Time", FinishTime);
        Alloc.Modify(true);
    end;

    local procedure ApplyOptionalFields()
    begin
        if not (ReasonSent or HasStart or HasFinish) then
            exit;
        if ReasonSent then
            Alloc.Validate("Reason Code", ReasonCode);
        if HasStart then
            Alloc.Validate("Starting Time", StartTime);
        if HasFinish then
            Alloc.Validate("Finishing Time", FinishTime);
        Alloc.Modify(true);
    end;

    local procedure AssertOneResource()
    var
        Other: Record "Service Order Allocation";
        Res: Record Resource;
        ResGr: Record "Resource Group";
        ItemLine: Record "Service Item Line";
    begin
        Other.SetLoadFields("Entry No.", Status, "Resource No.", "Resource Group No.");
        Other.SetRange("Document Type", Alloc."Document Type");
        Other.SetRange("Document No.", Alloc."Document No.");
        Other.SetRange("Service Item Line No.", Alloc."Service Item Line No.");
        Other.SetFilter("Entry No.", '<>%1', Alloc."Entry No.");
        Other.SetFilter(Status, '%1|%2', Other.Status::Active, Other.Status::"Reallocation Needed");
        if not Other.FindSet() then
            exit;
        repeat
            if ResourceSent and (Other."Resource No." <> '') and (Other."Resource No." <> ResourceNo) then
                Error(OnlyOneLbl, Res.TableCaption(), ItemLine.TableCaption());
            if GroupSent and (Other."Resource Group No." <> '') and (Other."Resource Group No." <> ResourceGroupNo) then
                Error(OnlyOneLbl, ResGr.TableCaption(), ItemLine.TableCaption());
        until Other.Next() = 0;
    end;

    local procedure WriteSuccess(var Argument: Record "Message Argument ori"; OldResource: Code[20]; OldGroup: Code[20])
    var
        ItemLine: Record "Service Item Line";
        History: Record "Service Order Allocation";
        Response: JsonObject;
        PreviousStatus: Text;
    begin
        Alloc.Get(Alloc."Entry No.");
        ItemLine.SetLoadFields("Repair Status Code");
        ItemLine.Get(Alloc."Document Type", Alloc."Document No.", Alloc."Service Item Line No.");
        Response.Add('status', 'Success');
        Response.Add('documentNo', Alloc."Document No.");
        Response.Add('serviceItemLineNo', Alloc."Service Item Line No.");
        Response.Add('serviceItemNo', Alloc."Service Item No.");
        Response.Add('entryNo', Alloc."Entry No.");
        Response.Add('allocationStatus', 'Active');
        Response.Add('resourceNo', Alloc."Resource No.");
        Response.Add('resourceGroupNo', Alloc."Resource Group No.");
        Response.Add('allocationDate', Format(Alloc."Allocation Date", 0, 9));
        Response.Add('allocatedHours', Alloc."Allocated Hours");
        Response.Add('reallocated', Reallocate);
        Response.Add('repairStatusCode', ItemLine."Repair Status Code");
        if Reallocate then
            if FindPrevious(History, OldResource, OldGroup) then begin
                if History.Status = History.Status::Finished then
                    PreviousStatus := 'Finished'
                else
                    PreviousStatus := 'Canceled';
                Response.Add('previousEntryNo', History."Entry No.");
                Response.Add('previousStatus', PreviousStatus);
            end;
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure FindPrevious(var History: Record "Service Order Allocation"; OldResource: Code[20]; OldGroup: Code[20]): Boolean
    begin
        History.SetLoadFields("Entry No.", Status, "Resource No.", "Resource Group No.");
        History.SetRange("Document Type", Alloc."Document Type");
        History.SetRange("Document No.", Alloc."Document No.");
        History.SetRange("Service Item Line No.", Alloc."Service Item Line No.");
        History.SetRange("Resource No.", OldResource);
        History.SetRange("Resource Group No.", OldGroup);
        History.SetFilter("Entry No.", '<>%1', Alloc."Entry No.");
        History.SetFilter(Status, '%1|%2', History.Status::Canceled, History.Status::Finished);
        exit(History.FindLast());
    end;

    local procedure ReadParameters(Request: JsonObject; var Argument: Record "Message Argument ori")
    var
        Subject: Text;
    begin
        ReadDocumentNo(Request, Argument);
        ReadSystemId(Request, Argument);
        RequestedEntryNo := ReadPositiveInteger(Request, 'entryNo', Argument, EntrySent);
        RequestedLineNo := ReadPositiveInteger(Request, 'serviceItemLineNo', Argument, LineSent);
        ResourceNo := CopyStr(ReadCode(Request, 'resourceNo', MaxStrLen(ResourceNo), Argument, ResourceSent), 1, MaxStrLen(ResourceNo));
        ResourceGroupNo := CopyStr(ReadCode(Request, 'resourceGroupNo', MaxStrLen(ResourceGroupNo), Argument, GroupSent), 1, MaxStrLen(ResourceGroupNo));
        AllocationDate := ReadDate(Request, Argument);
        Hours := ReadHours(Request, Argument);
        StartTime := ReadTime(Request, 'startingTime', Argument, HasStart);
        FinishTime := ReadTime(Request, 'finishingTime', Argument, HasFinish);
        ReasonCode := CopyStr(ReadCode(Request, 'reasonCode', MaxStrLen(ReasonCode), Argument, ReasonSent), 1, MaxStrLen(ReasonCode));
        AcceptOutside := ReadBoolean(Request, Argument);
        Subject := Argument.Subject.Trim();
        if StrLen(Subject) > MaxStrLen(Header."No.") then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(SubjectLbl, MaxStrLen(Header."No.")), 'subject', '', '', CorrectLbl);
        if not DocumentAttempted and not SystemAttempted and not EntrySent and (Subject = '') then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingIdentLbl, 'documentNo/systemId/entryNo', '', '', CorrectLbl);
        if not ResourceSent and not GroupSent then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, NoResourceLbl, 'resourceNo/resourceGroupNo', '', '', NoResourceLbl);
    end;

    local procedure CollectReferenceErrors(var Argument: Record "Message Argument ori")
    var
        Res: Record Resource;
        ResGr: Record "Resource Group";
        Reason: Record "Reason Code";
    begin
        if ResourceSent then begin
            Res.SetLoadFields("No.");
            if not Res.Get(ResourceNo) then
                Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ResourceMissingLbl, ResourceNo), 'resourceNo', ResourceNo, '', ReadResourceLbl);
        end;
        if GroupSent then begin
            ResGr.SetLoadFields("No.");
            if not ResGr.Get(ResourceGroupNo) then
                Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(GroupMissingLbl, ResourceGroupNo), 'resourceGroupNo', ResourceGroupNo, '', ReadGroupLbl);
        end;
        if ReasonSent then begin
            Reason.SetLoadFields(Code);
            if not Reason.Get(ReasonCode) then
                Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ReasonMissingLbl, ReasonCode), 'reasonCode', ReasonCode, '', ReadReasonLbl);
        end;
    end;

    local procedure ResolveDocument(var Argument: Record "Message Argument ori"): Boolean
    var
        Lookup: Codeunit "Svc Document Lookup ori";
    begin
        if DocumentAttempted or SystemAttempted or (Argument.Subject.Trim() <> '') then begin
            if not Lookup.FindAllocationDocument(Argument, Header) then
                exit(false);
            if not EntrySent then
                exit(true);
            if not GetEntry(Argument) then
                exit(false);
            if (Alloc."Document Type" <> Header."Document Type") or (Alloc."Document No." <> Header."No.") then begin
                Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'documentNo/systemId/entryNo', '', '', ConflictNextLbl);
                exit(false);
            end;
            exit(true);
        end;
        if not GetEntry(Argument) then
            exit(false);
        if Alloc."Document Type" <> Alloc."Document Type"::Order then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(OrderTypeLbl, Alloc."Document No.", DocumentTypeCaption(Alloc."Document Type")), 'entryNo', Format(Alloc."Entry No."), 'Order', OrderTypeNextLbl);
            exit(false);
        end;
        Header.SetLoadFields("Document Type", "No.", Status, "Service Zone Code");
        if not Header.Get(Alloc."Document Type", Alloc."Document No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryMissingLbl, Alloc."Entry No."), 'entryNo', Format(Alloc."Entry No."), '', ReadAllocLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure GetEntry(var Argument: Record "Message Argument ori"): Boolean
    begin
        if not Alloc.Get(RequestedEntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryMissingLbl, RequestedEntryNo), 'entryNo', Format(RequestedEntryNo), '', ReadAllocLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ResolveLine(var Argument: Record "Message Argument ori"): Boolean
    var
        ItemLine: Record "Service Item Line";
        LineNo: Integer;
    begin
        ItemLine.SetLoadFields("Document Type", "Document No.", "Line No.");
        ItemLine.SetRange("Document Type", Header."Document Type");
        ItemLine.SetRange("Document No.", Header."No.");
        if EntrySent then begin
            LineNo := Alloc."Service Item Line No.";
            if LineSent and (RequestedLineNo <> LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, LineConflictLbl, 'entryNo/serviceItemLineNo', '', '', LineConflictNextLbl);
                exit(false);
            end;
        end else
            if LineSent then begin
                ItemLine.SetRange("Line No.", RequestedLineNo);
                if ItemLine.IsEmpty() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineMissingLbl, RequestedLineNo, Header."No."), 'serviceItemLineNo', Format(RequestedLineNo), '', LineNextLbl);
                    exit(false);
                end;
                LineNo := RequestedLineNo;
            end else
                case ItemLine.Count() of
                    0:
                        begin
                            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NoLineLbl, Header."No."), 'documentNo', Header."No.", '', LineNextLbl);
                            exit(false);
                        end;
                    1:
                        begin
                            ItemLine.FindFirst();
                            LineNo := ItemLine."Line No.";
                        end;
                    else begin
                        Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, StrSubstNo(SeveralLinesLbl, Header."No."), 'serviceItemLineNo', '', '', SeveralLinesNextLbl);
                        exit(false);
                    end;
                end;
        RequestedLineNo := LineNo;
        exit(true);
    end;

    local procedure ResolveAllocation(var Argument: Record "Message Argument ori"): Boolean
    var
        OpenAlloc: Record "Service Order Allocation";
        OpenCount: Integer;
    begin
        if EntrySent then begin
            if not EntryIsOpen(Alloc) or (Alloc."Service Item Line No." <> RequestedLineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoOpenLbl, RequestedLineNo, Header."No."), 'entryNo', Format(Alloc."Entry No."), '', ReadAllocLbl);
                exit(false);
            end;
            exit(true);
        end;
        OpenAlloc.SetLoadFields("Entry No.", Status);
        OpenAlloc.SetRange("Document Type", Header."Document Type");
        OpenAlloc.SetRange("Document No.", Header."No.");
        OpenAlloc.SetRange("Service Item Line No.", RequestedLineNo);
        OpenAlloc.SetFilter(Status, '<>%1&<>%2', OpenAlloc.Status::Canceled, OpenAlloc.Status::Finished);
        OpenCount := OpenAlloc.Count();
        if OpenCount = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoOpenLbl, RequestedLineNo, Header."No."), 'serviceItemLineNo', Format(RequestedLineNo), '', ReadAllocLbl);
            exit(false);
        end;
        if OpenCount > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, StrSubstNo(SeveralOpenLbl, RequestedLineNo, Header."No."), 'entryNo', '', '', SeveralOpenNextLbl);
            exit(false);
        end;
        OpenAlloc.FindFirst();
        Alloc.Get(OpenAlloc."Entry No.");
        exit(true);
    end;

    local procedure EnsureZone(var Argument: Record "Message Argument ori"): Boolean
    var
        Setup: Record "Service Mgt. Setup";
        Res: Record Resource;
    begin
        if not ResourceSent or AcceptOutside then
            exit(true);
        Setup.SetLoadFields("Service Zones Option");
        Setup.Get();
        if Setup."Service Zones Option" <> Setup."Service Zones Option"::"Warning Displayed" then
            exit(true);
        Res.SetLoadFields("No.", "Service Zone Filter");
        Res.Get(ResourceNo);
        Res."Service Zone Filter" := Header."Service Zone Code";
        Res.CalcFields("In Customer Zone");
        if Res."In Customer Zone" then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ZoneLbl, ResourceNo, Header."Service Zone Code"), 'resourceNo', ResourceNo, Header."Service Zone Code", ZoneNextLbl);
        exit(false);
    end;

    local procedure EnsureWritable(var Argument: Record "Message Argument ori"): Boolean
    begin
        if OrderIsFinished() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(FinishedOrderLbl, Header."No."), 'documentNo', Header."No.", '', FinishedNextLbl);
            exit(false);
        end;
        if LineIsFinished() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(FinishedLineLbl, RequestedLineNo, Header."No."), 'serviceItemLineNo', Format(RequestedLineNo), '', FinishedNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure OrderIsFinished(): Boolean
    begin
        exit(Header.Status = Header.Status::Finished);
    end;

    local procedure LineIsFinished(): Boolean
    var
        ItemLine: Record "Service Item Line";
        RepairStatus: Record "Repair Status";
    begin
        ItemLine.SetLoadFields("Repair Status Code");
        if not ItemLine.Get(Header."Document Type", Header."No.", RequestedLineNo) then
            exit(false);
        if ItemLine."Repair Status Code" = '' then
            exit(false);
        RepairStatus.SetLoadFields(Finished);
        if not RepairStatus.Get(ItemLine."Repair Status Code") then
            exit(false);
        exit(RepairStatus.Finished);
    end;

    local procedure EntryIsOpen(OpenAlloc: Record "Service Order Allocation"): Boolean
    begin
        exit((OpenAlloc.Status <> OpenAlloc.Status::Canceled) and (OpenAlloc.Status <> OpenAlloc.Status::Finished));
    end;

    local procedure DocumentTypeCaption(DocumentType: Enum "Service Document Type"): Text
    var
        Lookup: Codeunit "Svc Document Lookup ori";
    begin
        exit(Lookup.TypeCaption(DocumentType));
    end;

    local procedure ReadDocumentNo(Request: JsonObject; var Argument: Record "Message Argument ori")
    var
        Token: JsonToken;
        Value: Text;
    begin
        if not Request.Get('documentNo', Token) then
            exit;
        DocumentAttempted := true;
        Value := ReadCodeValue(Token, 'documentNo', MaxStrLen(Header."No."), Argument);
        if Value = '' then
            exit;
    end;

    local procedure ReadSystemId(Request: JsonObject; var Argument: Record "Message Argument ori")
    var
        Token: JsonToken;
        Value: Text;
        Id: Guid;
    begin
        if not Request.Get('systemId', Token) then
            exit;
        SystemAttempted := true;
        Value := ReadCodeValue(Token, 'systemId', 50, Argument);
        if Value = '' then
            exit;
        if not Evaluate(Id, Value) or IsNullGuid(Id) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, GuidLbl, 'systemId', Value, 'GUID', CorrectLbl);
    end;

    local procedure ReadCode(Request: JsonObject; KeyName: Text; Maximum: Integer; var Argument: Record "Message Argument ori"; var Present: Boolean): Text
    var
        Token: JsonToken;
    begin
        if not Request.Get(KeyName, Token) then
            exit('');
        Present := true;
        exit(ReadCodeValue(Token, KeyName, Maximum, Argument));
    end;

    local procedure ReadCodeValue(Token: JsonToken; KeyName: Text; Maximum: Integer; var Argument: Record "Message Argument ori"): Text
    var
        Raw: Text;
        Value: Text;
    begin
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(StringLbl, KeyName, Maximum), KeyName, '', 'string', CorrectLbl);
            exit('');
        end;
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(StringLbl, KeyName, Maximum), KeyName, '', '', CorrectLbl);
        exit(Value);
    end;

    local procedure ReadPositiveInteger(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Present: Boolean): Integer
    var
        Token: JsonToken;
        Raw: Text;
        Value: Integer;
    begin
        if not Request.Get(KeyName, Token) then
            exit(0);
        Present := true;
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        if not IsWholeNumber(Raw) or not Evaluate(Value, Raw, 9) or (Value < 1) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(IntegerLbl, KeyName), KeyName, Raw, 'integer', CorrectLbl);
        exit(Value);
    end;

    local procedure ReadHours(Request: JsonObject; var Argument: Record "Message Argument ori"): Decimal
    var
        Token: JsonToken;
        Raw: Text;
        Value: Decimal;
    begin
        if not Request.Get('allocatedHours', Token) then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, HoursMissingLbl, 'allocatedHours', '', '', HoursNextLbl);
            exit(0);
        end;
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        if (CopyStr(Raw, 1, 1) = '"') or not Evaluate(Value, Raw, 9) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, HoursLbl, 'allocatedHours', Raw, 'number', HoursNextLbl);
            exit(0);
        end;
        if Value <= 0 then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, HoursLbl, 'allocatedHours', Raw, '> 0', HoursNextLbl);
        exit(Value);
    end;

    local procedure ReadDate(Request: JsonObject; var Argument: Record "Message Argument ori"): Date
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
        Parsed: Date;
    begin
        if not Request.Get('allocationDate', Token) then
            exit(WorkDate());
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, DateLbl, 'allocationDate', '', 'yyyy-mm-dd', CorrectLbl);
            exit(0D);
        end;
        Value := Token.AsValue().AsText().Trim();
        if not IsIsoDate(Value) or not Evaluate(Parsed, Value, 9) or (Parsed = 0D) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, DateLbl, 'allocationDate', Value, 'yyyy-mm-dd', CorrectLbl);
        exit(Parsed);
    end;

    local procedure ReadTime(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Present: Boolean): Time
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
        Parsed: Time;
    begin
        if not Request.Get(KeyName, Token) then
            exit(0T);
        Present := true;
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TimeLbl, KeyName), KeyName, '', 'hh:mm', CorrectLbl);
            exit(0T);
        end;
        Value := Token.AsValue().AsText().Trim();
        if not IsClock(Value) or not Evaluate(Parsed, Value) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TimeLbl, KeyName), KeyName, Value, 'hh:mm', CorrectLbl);
        exit(Parsed);
    end;

    local procedure ReadBoolean(Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get('acceptOutsideServiceZone', Token) then
            exit(false);
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        if Raw = 'true' then
            exit(true);
        if Raw = 'false' then
            exit(false);
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, BooleanLbl, 'acceptOutsideServiceZone', Raw, 'boolean', CorrectLbl);
        exit(false);
    end;

    local procedure IsWholeNumber(Raw: Text): Boolean
    var
        Index: Integer;
    begin
        if Raw = '' then
            exit(false);
        for Index := 1 to StrLen(Raw) do
            if not (CopyStr(Raw, Index, 1) in ['0' .. '9']) then
                exit(false);
        exit(true);
    end;

    local procedure IsIsoDate(Value: Text): Boolean
    begin
        exit((StrLen(Value) = 10) and (CopyStr(Value, 5, 1) = '-') and (CopyStr(Value, 8, 1) = '-'));
    end;

    local procedure IsClock(Value: Text): Boolean
    begin
        exit((StrLen(Value) = 5) and (CopyStr(Value, 3, 1) = ':'));
    end;

    local procedure ClearState()
    begin
        Clear(Header);
        Clear(Alloc);
        Clear(ResourceNo);
        Clear(ResourceGroupNo);
        Clear(ReasonCode);
        Clear(AllocationDate);
        Clear(StartTime);
        Clear(FinishTime);
        Clear(Hours);
        Clear(RequestedEntryNo);
        Clear(RequestedLineNo);
        DocumentAttempted := false;
        SystemAttempted := false;
        EntrySent := false;
        LineSent := false;
        ResourceSent := false;
        GroupSent := false;
        ReasonSent := false;
        HasStart := false;
        HasFinish := false;
        AcceptOutside := false;
        Reallocate := false;
    end;
}
