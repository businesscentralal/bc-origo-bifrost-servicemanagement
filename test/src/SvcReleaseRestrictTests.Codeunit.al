namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Exercises the generic dispatcher write guard and proves unrelated edits and reads remain available.</summary>
codeunit 97707 "Svc Release Restrict Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC10_ReleaseStatus_BlockedWithHint()
    var
        Header: Record "Service Header";
        Response: JsonObject;
        Serialized: Text;
    begin
        // Issue #4 AC10: trigger the real Data.Records.Set event, not the subscriber directly.
        Data.CreateDocument(Header, Header."Document Type"::Order);
        Commit();
        Response := SetField(Header.SystemId, 'ReleaseStatus', 'Released to Ship');
        Response.WriteTo(Serialized);
        Data.AssertRefusal(Response, 'PermissionDenied');
        Assert.IsTrue(Serialized.Contains('Service.Order.Release / Service.Order.Reopen'), 'Hint names both operations.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(Header."Release Status"::Open, Header."Release Status", 'Generic writer changed nothing.');
    end;

    [Test]
    procedure Scenario_AC10_OrdinaryFieldAndRead_RemainAllowed()
    var
        Header: Record "Service Header";
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
        Commit();
        // Exercise the ordinary field under a legitimate Change Log write-guard configuration.
        // No Foundation setup table is read or written, and dedicated restrictions remain active.
        HadLog := ChangeLog.Get();
        PriorLog := ChangeLog;
        if not HadLog then begin
            ChangeLog.Init();
            ChangeLog.Insert();
        end;
        ChangeLog."Change Log Activated" := true;
        ChangeLog.Modify();
        HadTable := ChangeLogTable.Get(Database::"Service Header");
        PriorTable := ChangeLogTable;
        if not HadTable then begin
            ChangeLogTable.Init();
            ChangeLogTable."Table No." := Database::"Service Header";
            ChangeLogTable.Insert();
        end;
        ChangeLogTable."Log Modification" := ChangeLogTable."Log Modification"::"All Fields";
        ChangeLogTable.Modify();
        Commit();
        Response := SetField(Header.SystemId, 'Description', 'X-service lifecycle test');
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
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Ordinary edit allowed.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual('X-service lifecycle test', Header.Description, 'Description persisted.');
        Request.Add('tableName', 'Service Header');
        Request.Add('tableView', 'WHERE(No.=CONST(' + Header."No." + '))');
        Response := Data.Invoke("Message Type ori"::"Data.Records.Get", Request, '', 1033, false);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains(Header."No."), 'Ordinary read remains allowed.');
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
        Request.Add('tableName', 'Service Header');
        Request.Add('data', Entries);
        exit(Data.Invoke("Message Type ori"::"Data.Records.Set", Request, '', 1033, false));
    end;
}
