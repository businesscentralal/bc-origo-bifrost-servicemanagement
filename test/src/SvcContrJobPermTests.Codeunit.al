namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Origo.Bifrost;
using Origo.Bifrost.ServiceManagement;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 25 service write-role boundaries on all four operations.</summary>
codeunit 97787 "Svc Contr Job Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Contr Job Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC06_ReadRoleDeniedAllOperations()
    begin
        // Story #25 AC06 | Risk: broad native execute permission bypasses the service write gate.
        CheckDenied('BIFROST Read ori');
    end;

    [Test]
    procedure Scenario_AC06_NoPermissionDeniedAllOperations()
    begin
        // Story #25 AC06 | Risk: callers without Foundation permissions mutate contracts.
        CheckDenied('Svc NoGrant Tst ori');
    end;

    [Test]
    procedure Scenario_AC06_FullRoleWithoutPostingTokenCanRunJobs()
    var
        Header: Record "Service Contract Header";
        PostingGate: Codeunit "Svc Posting Gate ori";
        Response: JsonObject;
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        ResponseText: Text;
        CanPost: Boolean;
    begin
        // AC06: unposted document creation requires the write role but no posting token.
        foreach TypeValue in Fixture.Types() do begin
            Fixture.Create(Header);
            if TypeValue = TypeValue::"Service.Contract.CreateCreditMemo" then
                Fixture.PrepareCredit(Header);
            Request := Fixture.Request(TypeValue, Header);
            Commit();
            LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
            LowerPermissions.AddPermissionSet('D365 BASIC');
            LowerPermissions.AddPermissionSet('D365 READ');
            LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
            LowerPermissions.AddPermissionSet('Svc Contract Tst ori');
            LowerPermissions.AddPermissionSet('Svc Jobs Tst ori');
            LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
            CanPost := PostingGate.HasPostingPermission();
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            LowerPermissions.SetOutsideO365Scope();
            Assert.IsFalse(CanPost, 'No posting token.');
            Response.WriteTo(ResponseText);
            Assert.AreEqual('Success', Data.TextValue(Response, 'status'), ResponseText);
            Fixture.Cleanup();
        end;
    end;

    local procedure CheckDenied(RoleName: Code[20])
    var
        Header: Record "Service Contract Header";
        Runner: Codeunit "Svc Doc Perm Runner ori";
        Types: List of [Enum "Message Type ori"];
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
        Failure: Text;
        Ran: Boolean;
    begin
        Types := Fixture.Types();
        foreach TypeValue in Types do begin
            Fixture.Create(Header);
            Request := Fixture.Request(TypeValue, Header);
            Commit();
            Clear(Runner);
            Runner.SetRequest(TypeValue, Request);
            LowerPermissions.SetExactPermissionSet(RoleName);
            LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
            if RoleName = 'BIFROST Read ori' then begin
                LowerPermissions.AddPermissionSet('D365 BASIC');
                LowerPermissions.AddPermissionSet('D365 READ');
                LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
                LowerPermissions.AddPermissionSet('Svc Contract Tst ori');
            LowerPermissions.AddPermissionSet('Svc Jobs Tst ori');
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
            Header.Get(Header."Contract Type", Header."Contract No.");
            Assert.AreEqual(Header.Status::Signed, Header.Status, 'Denied operation left status unchanged.');
            Assert.AreEqual(Header."Change Status"::Locked, Header."Change Status", 'Denied operation left change status unchanged.');
            Fixture.Cleanup();
        end;
    end;
}
