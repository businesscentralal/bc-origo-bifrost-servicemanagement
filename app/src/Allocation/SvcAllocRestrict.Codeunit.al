namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Keeps allocation status and resource identity on Service.Allocation.Allocate.</summary>
codeunit 10076064 "Svc Alloc Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictAllocationFields(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        if (TableNo = Database::"Service Order Allocation") and IsGuardedField(FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure AllocationFieldHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        HintLbl: Label 'Use Service.Allocation.Allocate', Comment = 'is-IS=Notaðu Service.Allocation.Allocate';
    begin
        if (TableNo = Database::"Service Order Allocation") and IsGuardedField(FieldNo) then
            Hint := HintLbl;
    end;

    local procedure IsGuardedField(FieldNo: Integer): Boolean
    var
        Alloc: Record "Service Order Allocation";
    begin
        if FieldNo = Alloc.FieldNo(Status) then
            exit(true);
        if FieldNo = Alloc.FieldNo("Resource No.") then
            exit(true);
        if FieldNo = Alloc.FieldNo("Resource Group No.") then
            exit(true);
        exit(false);
    end;
}
