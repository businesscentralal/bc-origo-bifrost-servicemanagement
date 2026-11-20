namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Checks posting-token, read-role and no-permission refusals for standalone billing.</summary>
codeunit 97758 "Svc Doc Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Doc Fixture ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC05_FullWithoutPostingToken_Refused()
    var
        Header: Record "Service Header";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        Response: JsonObject;
    begin
        // Story #22 AC05 | Time: WorkDate | Risk: Full must not grant posting.
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::"Credit Memo", CustomerNo, ResourceNo);
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365 READ');
        LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
        Response := Data.Invoke("Message Type ori"::"Service.Document.Post", Fixture.Request(Header, 1), '', 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Data.AssertRefusal(Response, 'PermissionDenied');
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'No posting.');
        Fixture.Cleanup();
    end;

    [Test]
    procedure Scenario_AC05_ReadRole_AllOperationsRefused()
    begin
        // Story #22 AC05 | Time: WorkDate | Risk: native broad execute must not bypass write gate.
        CheckDenied('BIFROST Read ori');
    end;

    [Test]
    procedure Scenario_AC05_NoPermission_AllOperationsRefused()
    begin
        // Story #22 AC05 | Time: WorkDate | Risk: no access to Foundation or service records.
        CheckDenied('Svc NoGrant Tst ori');
    end;

    local procedure CheckDenied(RoleName: Code[20])
    var
        Header: Record "Service Header";
        Runner: Codeunit "Svc Doc Perm Runner ori";
        Request: JsonObject;
        Response: JsonObject;
        MessageType: Enum "Message Type ori";
        CustomerNo: Code[20];
        ResourceNo: Code[20];
        Failure: Text;
        Pass: Integer;
        Ran: Boolean;
    begin
        Fixture.Create(CustomerNo, ResourceNo);
        Fixture.Document(Header, Header."Document Type"::"Credit Memo", CustomerNo, ResourceNo);
        Commit();
        for Pass := 1 to 3 do begin
            Clear(Runner);
            Request := Fixture.Request(Header, 1);
            case Pass of
                1: MessageType := "Message Type ori"::"Service.Document.Post";
                2: MessageType := "Message Type ori"::"Service.Document.PreviewPost";
                3: begin
                    MessageType := "Message Type ori"::"Service.Invoice.GetShipmentLines";
                    Clear(Request);
                    Request.Add('customerNo', CustomerNo);
                    Request.Add('allUninvoiced', true);
                end;
            end;
            Runner.SetRequest(MessageType, Request);
            LowerPermissions.SetExactPermissionSet(RoleName);
            LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
            if RoleName = 'BIFROST Read ori' then begin
                LowerPermissions.AddPermissionSet('D365 BASIC');
                LowerPermissions.AddPermissionSet('D365 READ');
                LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
            end;
            ClearLastError();
            Ran := Runner.Run();
            Failure := GetLastErrorText();
            LowerPermissions.SetOutsideO365Scope();
            if Ran then begin
                Response := Runner.GetResponse();
                Data.AssertRefusal(Response, 'PermissionDenied');
            end else
                Assert.IsTrue(LowerCase(Failure).Contains('permission'), Failure);
            Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'No posting.');
        end;
        Fixture.Cleanup();
    end;
}
