namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Keeps allocation status and resource identity on Service.Allocation.Allocate.</summary>
codeunit 97727 "Svc Alloc Restrict Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_GuardedFields_PermissionDeniedWithHint()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        Response: JsonObject;
        Serialized: Text;
    begin
        // Foundation's dedicated-field answer is PermissionDenied. BlockedByWriteGuard is a different code and is not returned here.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.FindAllocation(Header, Alloc);
        Commit();
        // Foundation keeps the period in "Resource No." as an underscore, so the bare camelCase key is not that field.
        Response := SetField(Alloc.SystemId, 'Resource No.', 'X-BLOCKED');
        Response.WriteTo(Serialized);
        Data.AssertRefusal(Response, 'PermissionDenied');
        Assert.IsTrue(Serialized.Contains('Service.Allocation.Allocate'), 'Hint names the allocation message type.');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual('', Alloc."Resource No.", 'Generic writer changed no resource.');
        Response := SetField(Alloc.SystemId, 'Status', 'Active');
        Data.AssertRefusal(Response, 'PermissionDenied');
        Response := SetField(Alloc.SystemId, 'Resource Group No.', 'X-BLOCKED');
        Data.AssertRefusal(Response, 'PermissionDenied');
    end;

    [Test]
    procedure Scenario_HoursAndRead_RemainAllowed()
    var
        Header: Record "Service Header";
        Alloc: Record "Service Order Allocation";
        ChangeLog: Record "Change Log Setup";
        ChangeLogTable: Record "Change Log Setup (Table)";
        PriorLog: Record "Change Log Setup";
        PriorTable: Record "Change Log Setup (Table)";
        HadLog: Boolean;
        HadTable: Boolean;
        Request: JsonObject;
        Response: JsonObject;
        Serialized: Text;
    begin
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Data.FindAllocation(Header, Alloc);
        Commit();
        HadLog := ChangeLog.Get();
        PriorLog := ChangeLog;
        if not HadLog then begin
            ChangeLog.Init();
            ChangeLog.Insert();
        end;
        ChangeLog."Change Log Activated" := true;
        ChangeLog.Modify();
        HadTable := ChangeLogTable.Get(Database::"Service Order Allocation");
        PriorTable := ChangeLogTable;
        if not HadTable then begin
            ChangeLogTable.Init();
            ChangeLogTable."Table No." := Database::"Service Order Allocation";
            ChangeLogTable.Insert();
        end;
        ChangeLogTable."Log Modification" := ChangeLogTable."Log Modification"::"All Fields";
        ChangeLogTable.Modify();
        Commit();
        Response := SetNumber(Alloc.SystemId, 'AllocatedHours', 4);
        if HadTable then begin
            ChangeLogTable := PriorTable;
            ChangeLogTable.Modify();
        end else
            ChangeLogTable.Delete();
        if HadLog then begin
            ChangeLog := PriorLog;
            ChangeLog.Modify();
        end else
            ChangeLog.Delete();
        Commit();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Allocated Hours stays writable.');
        Alloc.Get(Alloc."Entry No.");
        Assert.AreEqual(4, Alloc."Allocated Hours", 'Hours persisted.');
        Request.Add('tableName', 'Service Order Allocation');
        Request.Add('tableView', 'WHERE(Entry No.=CONST(' + Format(Alloc."Entry No.") + '))');
        Response := Data.Invoke("Message Type ori"::"Data.Records.Get", Request, '', 1033, false);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains(Format(Alloc."Entry No.")), 'Ordinary read remains allowed.');
    end;

    local procedure SetField(Id: Guid; FieldName: Text; Value: Text): JsonObject
    var
        Request: JsonObject;
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
    begin
        Fields.Add(FieldName, Value);
        Entry.Add('id', Format(Id, 0, 4));
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Request.Add('tableName', 'Service Order Allocation');
        Request.Add('data', Entries);
        exit(Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', 1033, false));
    end;

    local procedure SetNumber(Id: Guid; FieldName: Text; Value: Decimal): JsonObject
    var
        Request: JsonObject;
        Entry: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
    begin
        Fields.Add(FieldName, Value);
        Entry.Add('id', Format(Id, 0, 4));
        Entry.Add('fields', Fields);
        Entries.Add(Entry);
        Request.Add('tableName', 'Service Order Allocation');
        Request.Add('data', Entries);
        exit(Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', 1033, false));
    end;
}
