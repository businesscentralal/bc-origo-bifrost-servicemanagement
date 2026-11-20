namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.History;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Proves read-role, Full-without-posting and no-permission callers cannot undo service shipment or consumption lines.</summary>
codeunit 97752 "Svc Undo Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        UndoData: Codeunit "Svc Undo Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC06_FullWithoutPostingSet_PermissionDenied()
    var
        Header: Record "Service Header";
        Line: Record "Service Shipment Line";
        Response: JsonObject;
        ShipmentNo: Code[20];
        Serialized: Text;
        Consumption: Boolean;
        Pass: Integer;
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, Line.Type::Item, Line);
        for Pass := 0 to 1 do begin
            Consumption := Pass = 1;
            LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
            AddNativePermissions();
            Response := UndoData.UndoLine(Consumption, ShipmentNo, Line."Line No.");
            LowerPermissions.SetOutsideO365Scope();
            Response.WriteTo(Serialized);
            Data.AssertRefusal(Response, 'PermissionDenied');
            Assert.IsTrue(Serialized.Contains('BIFROST SvcPost ori'), 'The refusal names the permission set.');
            Assert.AreEqual(0, UndoData.CorrectionLines(ShipmentNo), 'Nothing is posted.');
        end;
    end;

    [Test]
    procedure Scenario_AC06_ReadRole_Refused()
    begin
        AssertRefused('BIFROST Read ori');
    end;

    [Test]
    procedure Scenario_AC06_NoPermission_Refused()
    begin
        AssertRefused('');
    end;

    local procedure AssertRefused(RoleSet: Text)
    var
        Header: Record "Service Header";
        Line: Record "Service Shipment Line";
        Runner: Codeunit "Svc Undo Perm Runner ori";
        Response: JsonObject;
        ShipmentNo: Code[20];
        Serialized: Text;
        ErrorText: Text;
        Consumption: Boolean;
        Pass: Integer;
    begin
        ShipmentNo := UndoData.ShipOrder(Header, false);
        UndoData.FindLine(ShipmentNo, Line.Type::Item, Line);
        for Pass := 0 to 1 do begin
            Consumption := Pass = 1;
            ClearLastError();
            if RoleSet <> '' then
                LowerPermissions.SetExactPermissionSet(CopyStr(RoleSet, 1, 20))
            else
                LowerPermissions.SetExactPermissionSet('Svc NoGrant Tst ori');
            AddNativePermissions();
            Serialized := '';
            Clear(Runner);
            Runner.SetRequest(Consumption, ShipmentNo, Line."Line No.");
            if Runner.Run() then begin
                Response := Runner.GetResponse();
                Response.WriteTo(Serialized);
            end
            else
                ErrorText := GetLastErrorText();
            LowerPermissions.SetOutsideO365Scope();
            if Serialized <> '' then
                Data.AssertRefusal(Response, 'PermissionDenied')
            else
                Assert.IsTrue(ErrorText.Contains('permission') or ErrorText.Contains('Permission'), 'Platform must deny execution: ' + ErrorText);
            Assert.AreEqual(0, UndoData.CorrectionLines(ShipmentNo), 'Nothing is posted.');
        end;
    end;

    local procedure AddNativePermissions()
    begin
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
        LowerPermissions.AddPermissionSet('D365 READ');
        LowerPermissions.AddPermissionSet('D365 SALES DOC, POST');
        LowerPermissions.AddPermissionSet('D365 INV DOC, POST');
        LowerPermissions.AddPermissionSet('D365 JOURNALS, POST');
        LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
    end;
}
