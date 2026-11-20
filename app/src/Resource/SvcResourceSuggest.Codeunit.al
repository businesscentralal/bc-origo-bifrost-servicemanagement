namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Microsoft.Service.Resources;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>Ranks resources for a service item line by skills, service zone and free hours, using standard Business Central qualification. Writes nothing.</summary>
codeunit 10076132 "Svc Resource Suggest ori"
{
    Access = Internal;

    var
        ItemLine: Record "Service Item Line";
        Header: Record "Service Header";
        DocumentNo: Code[20];
        ResourceGroupNo: Code[20];
        LineNo: Integer;
        SystemIdValue: Guid;
        DateFrom: Date;
        DateTo: Date;
        TopCount: Integer;
        DocumentSent: Boolean;
        LineSent: Boolean;
        SystemIdSent: Boolean;
        GroupSent: Boolean;
        IncludeUnqualified: Boolean;
        SkillsApplied: Boolean;
        ZonesApplied: Boolean;
        RankedNos: List of [Code[20]];
        RankedQualified: List of [Boolean];
        RankedInZone: List of [Boolean];
        RankedAvailable: List of [Decimal];
        CorrectLbl: Label 'Send the value in the format documented by describe_message_type.', Comment = 'is-IS=Sendu gildið á sniðinu sem describe_message_type lýsir.';
        StringLbl: Label '%1 must be a nonempty JSON string of at most %2 characters.', Comment = '%1 = parameter, %2 = maximum, is-IS=%1 verður að vera JSON-strengur sem er ekki tómur og er að hámarki %2 stafir.';
        GuidLbl: Label 'systemId must be a nonempty GUID.', Comment = 'is-IS=systemId verður að vera gilt GUID sem er ekki tómt.';
        IntegerLbl: Label '%1 must be a positive whole number.', Comment = '%1 = parameter, is-IS=%1 verður að vera jákvæð heiltala.';
        TopLbl: Label 'top must be a whole number from 1 to 100.', Comment = 'is-IS=top verður að vera heiltala frá 1 til 100.';
        DateLbl: Label '%1 must be a yyyy-mm-dd date.', Comment = '%1 = parameter, is-IS=%1 verður að vera dagsetning á sniðinu yyyy-mm-dd.';
        BooleanLbl: Label 'includeUnqualified must be a JSON boolean.', Comment = 'is-IS=includeUnqualified verður að vera JSON boolean.';
        PeriodLbl: Label 'The period from %1 to %2 is longer than 31 days.', Comment = '%1 = first date, %2 = last date, is-IS=Tímabilið frá %1 til %2 er lengra en 31 dagur.';
        PeriodNextLbl: Label 'Send dateFrom and dateTo at most 31 days apart.', Comment = 'is-IS=Sendu dateFrom og dateTo með að hámarki 31 dags millibili.';
        OrderLbl: Label 'dateTo %1 is before dateFrom %2.', Comment = '%1 = last date, %2 = first date, is-IS=dateTo %1 er á undan dateFrom %2.';
        OrderNextLbl: Label 'Send a dateTo on or after dateFrom.', Comment = 'is-IS=Sendu dateTo sem er sama dag eða á eftir dateFrom.';
        MissingLineLbl: Label 'Send documentNo with serviceItemLineNo, or systemId of a service item line.', Comment = 'is-IS=Sendu documentNo ásamt serviceItemLineNo, eða systemId þjónustuvörulínu.';
        MissingLineNoLbl: Label 'Send serviceItemLineNo with documentNo.', Comment = 'is-IS=Sendu serviceItemLineNo ásamt documentNo.';
        MissingDocumentLbl: Label 'Send documentNo with serviceItemLineNo.', Comment = 'is-IS=Sendu documentNo ásamt serviceItemLineNo.';
        LineMissingLbl: Label 'Service item line %1 was not found on service order %2.', Comment = '%1 = line number, %2 = order number, is-IS=Þjónustuvörulína %1 fannst ekki á þjónustupöntun %2.';
        SystemMissingLbl: Label 'No service item line has systemId %1.', Comment = '%1 = GUID, is-IS=Engin þjónustuvörulína er með systemId %1.';
        ReadLineLbl: Label 'Read service item lines with Data.Records.Get (table Service Item Line).', Comment = 'is-IS=Lestu þjónustuvörulínur með Data.Records.Get (tafla Service Item Line).';
        NotOrderLbl: Label 'Service item line %1 belongs to service document %2, which is not an order.', Comment = '%1 = line number, %2 = document number, is-IS=Þjónustuvörulína %1 tilheyrir þjónustuskjali %2 sem er ekki pöntun.';
        NotOrderNextLbl: Label 'Send a service item line of a service order.', Comment = 'is-IS=Sendu þjónustuvörulínu þjónustupöntunar.';
        ConflictLbl: Label 'systemId does not identify service item line %1 of service order %2.', Comment = '%1 = line number, %2 = order number, is-IS=systemId vísar ekki á þjónustuvörulínu %1 í þjónustupöntun %2.';
        ConflictNextLbl: Label 'Send identifiers belonging to the same service item line.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sömu þjónustuvörulínunni.';
        GroupMissingLbl: Label 'Resource group %1 was not found.', Comment = '%1 = resource group, is-IS=Forðaflokkur %1 fannst ekki.';
        ReadGroupLbl: Label 'Read resource groups with Data.Records.Get (table Resource Group).', Comment = 'is-IS=Lestu forðaflokka með Data.Records.Get (tafla Resource Group).';
        DeniedLbl: Label 'You do not have permission to read %1.', Comment = '%1 = table caption, is-IS=Þú hefur ekki heimild til að lesa %1.';
        ProblemsLbl: Label 'Several parameters are invalid. Nothing was read.', Comment = 'is-IS=Nokkrar færibreytur eru ógildar. Ekkert var lesið.';
        DeniedNextLbl: Label 'Ask an administrator for read access to service management and resources.', Comment = 'is-IS=Biddu kerfisstjóra um lesaðgang að þjónustustjórnun og forða.';

    /// <summary>Reads the request, resolves the service item line and returns the ranked resources.</summary>
    internal procedure Execute(var Argument: Record "Message Argument ori")
    begin
        if not CanRead(Argument) then
            exit;
        ReadParameters(Argument.GetRequestJson(), Argument);
        if Argument.HasCollectedErrors() then begin
            Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, ProblemsLbl);
            exit;
        end;
        if not ResolveLine(Argument) then
            exit;
        if GroupSent then
            if not ResourceGroupExists() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(GroupMissingLbl, ResourceGroupNo), 'resourceGroupNo', ResourceGroupNo, '', ReadGroupLbl);
                exit;
            end;
        Rank();
        WriteSuccess(Argument);
    end;

    local procedure CanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        Setup: Record "Service Mgt. Setup";
        Resource: Record Resource;
        ResourceSkill: Record "Resource Skill";
        ResourceZone: Record "Resource Service Zone";
        Capacity: Record "Res. Capacity Entry";
        Alloc: Record "Service Order Allocation";
    begin
        if not Header.ReadPermission() then
            exit(Denied(Argument, Header.TableCaption()));
        if not ItemLine.ReadPermission() then
            exit(Denied(Argument, ItemLine.TableCaption()));
        if not Setup.ReadPermission() then
            exit(Denied(Argument, Setup.TableCaption()));
        if not Resource.ReadPermission() then
            exit(Denied(Argument, Resource.TableCaption()));
        if not ResourceSkill.ReadPermission() then
            exit(Denied(Argument, ResourceSkill.TableCaption()));
        if not ResourceZone.ReadPermission() then
            exit(Denied(Argument, ResourceZone.TableCaption()));
        if not Capacity.ReadPermission() then
            exit(Denied(Argument, Capacity.TableCaption()));
        if not Alloc.ReadPermission() then
            exit(Denied(Argument, Alloc.TableCaption()));
        exit(true);
    end;

    local procedure Denied(var Argument: Record "Message Argument ori"; TableCaption: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(DeniedLbl, TableCaption), '', '', '', DeniedNextLbl);
        exit(false);
    end;

    local procedure ReadParameters(Request: JsonObject; var Argument: Record "Message Argument ori")
    var
        Value: Text;
    begin
        DocumentNo := CopyStr(ReadCode(Request, 'documentNo', MaxStrLen(DocumentNo), Argument, DocumentSent), 1, MaxStrLen(DocumentNo));
        LineNo := ReadInteger(Request, 'serviceItemLineNo', Argument, LineSent);
        Value := ReadCode(Request, 'systemId', 50, Argument, SystemIdSent);
        if SystemIdSent and (Value <> '') then
            if not Evaluate(SystemIdValue, Value) or IsNullGuid(SystemIdValue) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, GuidLbl, 'systemId', Value, 'GUID', CorrectLbl);
        ResourceGroupNo := CopyStr(ReadCode(Request, 'resourceGroupNo', MaxStrLen(ResourceGroupNo), Argument, GroupSent), 1, MaxStrLen(ResourceGroupNo));
        DateFrom := ReadDate(Request, 'dateFrom', WorkDate(), Argument);
        DateTo := ReadDate(Request, 'dateTo', DateFrom, Argument);
        IncludeUnqualified := ReadBoolean(Request, Argument);
        TopCount := ReadTop(Request, Argument);
        if (DateFrom <> 0D) and (DateTo <> 0D) then
            if DateTo < DateFrom then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(OrderLbl, Format(DateTo, 0, 9), Format(DateFrom, 0, 9)), 'dateTo', Format(DateTo, 0, 9), '>= dateFrom', OrderNextLbl)
            else
                if DateTo - DateFrom + 1 > 31 then
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(PeriodLbl, Format(DateFrom, 0, 9), Format(DateTo, 0, 9)), 'dateTo', Format(DateTo, 0, 9), '<= dateFrom + 30 days', PeriodNextLbl);
        if not SystemIdSent then
            case true of
                not DocumentSent and not LineSent:
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingLineLbl, 'documentNo/serviceItemLineNo/systemId', '', '', MissingLineLbl);
                DocumentSent and not LineSent:
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingLineNoLbl, 'serviceItemLineNo', '', '', MissingLineNoLbl);
                LineSent and not DocumentSent:
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingDocumentLbl, 'documentNo', '', '', MissingDocumentLbl);
            end;
    end;

    local procedure ResolveLine(var Argument: Record "Message Argument ori"): Boolean
    var
        ByNumber: Record "Service Item Line";
    begin
        if DocumentSent and LineSent then
            if not ByNumber.Get(ByNumber."Document Type"::Order, DocumentNo, LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineMissingLbl, LineNo, DocumentNo), 'serviceItemLineNo', Format(LineNo), '', ReadLineLbl);
                exit(false);
            end;
        if SystemIdSent then begin
            if not ItemLine.GetBySystemId(SystemIdValue) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SystemMissingLbl, Format(SystemIdValue, 0, 4)), 'systemId', Format(SystemIdValue, 0, 4), '', ReadLineLbl);
                exit(false);
            end;
            if (DocumentSent and (ItemLine."Document No." <> DocumentNo)) or (LineSent and (ItemLine."Line No." <> LineNo)) or
               (DocumentSent and LineSent and (ItemLine.SystemId <> ByNumber.SystemId))
            then begin
                Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(ConflictLbl, ItemLine."Line No.", ItemLine."Document No."), 'systemId', Format(SystemIdValue, 0, 4), '', ConflictNextLbl);
                exit(false);
            end;
        end else
            ItemLine := ByNumber;
        if ItemLine."Document Type" <> ItemLine."Document Type"::Order then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NotOrderLbl, ItemLine."Line No.", ItemLine."Document No."), 'systemId', Format(SystemIdValue, 0, 4), 'Order', NotOrderNextLbl);
            exit(false);
        end;
        Header.SetLoadFields("Document Type", "No.", "Service Zone Code");
        Header.Get(ItemLine."Document Type", ItemLine."Document No.");
        exit(true);
    end;

    local procedure ResourceGroupExists(): Boolean
    var
        ResourceGroup: Record "Resource Group";
    begin
        exit(ResourceGroup.Get(ResourceGroupNo));
    end;

    local procedure Rank()
    var
        Setup: Record "Service Mgt. Setup";
        Resource: Record Resource;
        AllocationMgt: Codeunit ServAllocationManagement;
        Qualified: Boolean;
        InZone: Boolean;
        Available: Decimal;
    begin
        Setup.SetLoadFields("Resource Skills Option", "Service Zones Option");
        if not Setup.Get() then
            Clear(Setup);
        SkillsApplied := Setup."Resource Skills Option" <> Setup."Resource Skills Option"::"Not Used";
        ZonesApplied := (Setup."Service Zones Option" <> Setup."Service Zones Option"::"Not Used") and (Header."Service Zone Code" <> '');
        Resource.SetRange(Blocked, false);
        if GroupSent then
            Resource.SetRange("Resource Group No.", ResourceGroupNo);
        Resource.SetRange("Date Filter", DateFrom, DateTo);
        Resource.SetAutoCalcFields("Qty. on Service Order");
        Resource.SetLoadFields("No.", Blocked, "Resource Group No.");
        if Resource.FindSet() then
            repeat
                Qualified := SkillsApplied and AllocationMgt.QualifiedForServiceItemLine(ItemLine, Resource."No.");
                if Qualified or not SkillsApplied or IncludeUnqualified then begin
                    InZone := ZonesApplied and WorksInZone(Resource."No.");
                    Available := CapacityHours(Resource."No.") - Resource."Qty. on Service Order";
                    InsertRanked(Resource."No.", Qualified, InZone, Available);
                end;
            until Resource.Next() = 0;
    end;

    /// <summary>Same test as the resource In Customer Zone field: the resource has the order service zone.</summary>
    local procedure WorksInZone(ResourceNo: Code[20]): Boolean
    var
        ResourceZone: Record "Resource Service Zone";
    begin
        ResourceZone.SetRange("Resource No.", ResourceNo);
        ResourceZone.SetRange("Service Zone Code", Header."Service Zone Code");
        exit(not ResourceZone.IsEmpty());
    end;

    /// <summary>Same sum as the resource Capacity field for the period.</summary>
    local procedure CapacityHours(ResourceNo: Code[20]): Decimal
    var
        Capacity: Record "Res. Capacity Entry";
    begin
        Capacity.SetRange("Resource No.", ResourceNo);
        Capacity.SetRange(Date, DateFrom, DateTo);
        Capacity.CalcSums(Capacity);
        exit(Capacity.Capacity);
    end;

    local procedure InsertRanked(No: Code[20]; Qualified: Boolean; InZone: Boolean; Available: Decimal)
    var
        Index: Integer;
    begin
        // AL does not short-circuit "and": check the bound before comparing with an entry.
        Index := 1;
        while Index <= RankedNos.Count() do begin
            if Before(No, Qualified, InZone, Available, Index) then
                break;
            Index += 1;
        end;
        if Index > TopCount then
            exit;
        RankedNos.Insert(Index, No);
        RankedQualified.Insert(Index, Qualified);
        RankedInZone.Insert(Index, InZone);
        RankedAvailable.Insert(Index, Available);
        if RankedNos.Count() > TopCount then begin
            RankedNos.RemoveAt(RankedNos.Count());
            RankedQualified.RemoveAt(RankedQualified.Count());
            RankedInZone.RemoveAt(RankedInZone.Count());
            RankedAvailable.RemoveAt(RankedAvailable.Count());
        end;
    end;

    local procedure Before(No: Code[20]; Qualified: Boolean; InZone: Boolean; Available: Decimal; Index: Integer): Boolean
    begin
        if Qualified <> RankedQualified.Get(Index) then
            exit(Qualified);
        if InZone <> RankedInZone.Get(Index) then
            exit(InZone);
        if Available <> RankedAvailable.Get(Index) then
            exit(Available > RankedAvailable.Get(Index));
        exit(No < RankedNos.Get(Index));
    end;

    local procedure WriteSuccess(var Argument: Record "Message Argument ori")
    var
        Resource: Record Resource;
        Response: JsonObject;
        Entry: JsonObject;
        Resources: JsonArray;
        Index: Integer;
        NullValue: JsonValue;
    begin
        NullValue.SetValueToNull();
        Resource.SetRange("Date Filter", DateFrom, DateTo);
        Resource.SetAutoCalcFields("Qty. on Service Order");
        Resource.SetLoadFields("No.", Name, "Resource Group No.");
        for Index := 1 to RankedNos.Count() do begin
            Resource.Get(RankedNos.Get(Index));
            Clear(Entry);
            Entry.Add('resourceNo', Resource."No.");
            Entry.Add('name', Resource.Name);
            Entry.Add('resourceGroupNo', Resource."Resource Group No.");
            if SkillsApplied then
                Entry.Add('qualified', RankedQualified.Get(Index))
            else
                Entry.Add('qualified', NullValue);
            if ZonesApplied then
                Entry.Add('inServiceZone', RankedInZone.Get(Index))
            else
                Entry.Add('inServiceZone', NullValue);
            Entry.Add('capacity', CapacityHours(Resource."No."));
            Entry.Add('allocatedHours', Resource."Qty. on Service Order");
            Entry.Add('availableHours', RankedAvailable.Get(Index));
            Resources.Add(Entry);
        end;
        Response.Add('status', 'Success');
        Response.Add('documentNo', ItemLine."Document No.");
        Response.Add('serviceItemLineNo', ItemLine."Line No.");
        Response.Add('serviceZoneCode', Header."Service Zone Code");
        Response.Add('dateFrom', Format(DateFrom, 0, 9));
        Response.Add('dateTo', Format(DateTo, 0, 9));
        Response.Add('skillsApplied', SkillsApplied);
        Response.Add('zonesApplied', ZonesApplied);
        Response.Add('count', Resources.Count());
        Response.Add('resources', Resources);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadCode(Request: JsonObject; KeyName: Text; Maximum: Integer; var Argument: Record "Message Argument ori"; var Present: Boolean): Text
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
    begin
        if not Request.Get(KeyName, Token) then
            exit('');
        Present := true;
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(StringLbl, KeyName, Maximum), KeyName, '', 'string', CorrectLbl);
            exit('');
        end;
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(StringLbl, KeyName, Maximum), KeyName, '', '', CorrectLbl);
            exit('');
        end;
        exit(Value);
    end;

    local procedure ReadInteger(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Present: Boolean): Integer
    var
        Token: JsonToken;
        Raw: Text;
        Value: Integer;
    begin
        if not Request.Get(KeyName, Token) then
            exit(0);
        Present := true;
        Token.WriteTo(Raw);
        if not IsWholeNumber(Raw) or not Evaluate(Value, Raw, 9) or (Value < 1) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(IntegerLbl, KeyName), KeyName, Raw, 'integer', CorrectLbl);
            exit(0);
        end;
        exit(Value);
    end;

    local procedure ReadTop(Request: JsonObject; var Argument: Record "Message Argument ori"): Integer
    var
        Token: JsonToken;
        Raw: Text;
        Value: Integer;
    begin
        if not Request.Get('top', Token) then
            exit(20);
        Token.WriteTo(Raw);
        if not IsWholeNumber(Raw) or not Evaluate(Value, Raw, 9) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, TopLbl, 'top', Raw, 'integer', CorrectLbl);
            exit(20);
        end;
        if (Value < 1) or (Value > 100) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, TopLbl, 'top', Raw, '1..100', CorrectLbl);
            exit(20);
        end;
        exit(Value);
    end;

    local procedure ReadDate(Request: JsonObject; KeyName: Text; DefaultDate: Date; var Argument: Record "Message Argument ori"): Date
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
        Result: Date;
    begin
        if not Request.Get(KeyName, Token) then
            exit(DefaultDate);
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateLbl, KeyName), KeyName, Raw, 'yyyy-mm-dd', CorrectLbl);
            exit(0D);
        end;
        Value := Token.AsValue().AsText().Trim();
        if not IsIsoDate(Value) or not Evaluate(Result, Value, 9) or (Result = 0D) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateLbl, KeyName), KeyName, Value, 'yyyy-mm-dd', CorrectLbl);
            exit(0D);
        end;
        exit(Result);
    end;

    local procedure ReadBoolean(Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get('includeUnqualified', Token) then
            exit(false);
        Token.WriteTo(Raw);
        case Raw of
            'true':
                exit(true);
            'false':
                exit(false);
        end;
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, BooleanLbl, 'includeUnqualified', Raw, 'boolean', CorrectLbl);
        exit(false);
    end;

    local procedure IsWholeNumber(Raw: Text): Boolean
    begin
        if Raw = '' then
            exit(false);
        exit(DelChr(Raw, '=', '0123456789') = '');
    end;

    local procedure IsIsoDate(Value: Text): Boolean
    begin
        exit((StrLen(Value) = 10) and (CopyStr(Value, 5, 1) = '-') and (CopyStr(Value, 8, 1) = '-') and (DelChr(Value, '=', '0123456789-') = ''));
    end;
}
