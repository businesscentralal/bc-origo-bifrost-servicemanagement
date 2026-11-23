namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Contract;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Verifies issue 24 service write-role boundaries on all four operations.</summary>
codeunit 97766 "Svc Contract Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Contract Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC06_ReadRoleDeniedAllOperations()
    begin
        // Story #24 AC06 | Risk: broad native execute permission bypasses the service write gate.
        CheckDenied('BIFROST Read ori');
    end;

    [Test]
    procedure Scenario_AC06_NoPermissionDeniedAllOperations()
    begin
        // Story #24 AC06 | Risk: callers without Foundation permissions mutate contracts.
        CheckDenied('Svc NoGrant Tst ori');
    end;

    [Test]
    procedure Scenario_AC06_FullRoleWithoutPostingTokenCanSign()
    var
        Header: Record "Service Contract Header";
        Response: JsonObject;
        TypeValue: Enum "Message Type ori";
        Request: JsonObject;
        Pass: Integer;
    begin
        // Story #24 AC06 | Risk: native signing accidentally requires the separate posting token.
        for Pass := 1 to 2 do begin
            Fixture.Create(Header, Pass = 1);
            TypeValue := "Message Type ori"::"Service.Contract.Sign";
            if Pass = 1 then
                TypeValue := "Message Type ori"::"Service.ContractQuote.MakeContract";
            Request := Fixture.Request(Header, true);
            Commit();
            LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
            LowerPermissions.AddPermissionSet('D365 BASIC');
            LowerPermissions.AddPermissionSet('D365 READ');
            LowerPermissions.AddPermissionSet('D365PREM SMG, EDIT');
            LowerPermissions.AddPermissionSet('Svc NoGrant Tst ori');
            Response := Data.Invoke(TypeValue, Request, '', 1033, false);
            LowerPermissions.SetOutsideO365Scope();
            Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Data.TextValue(Response, 'status'));
            Header.Get(Header."Contract Type"::Contract, Header."Contract No.");
            Assert.AreEqual(Header.Status::Signed, Header.Status, 'Full role signs without posting token.');
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
        Types.Add("Message Type ori"::"Service.ContractQuote.MakeContract");
        Types.Add("Message Type ori"::"Service.Contract.Sign");
        Types.Add("Message Type ori"::"Service.Contract.Lock");
        Types.Add("Message Type ori"::"Service.Contract.Unlock");
        foreach TypeValue in Types do begin
            Fixture.Create(Header, TypeValue = "Message Type ori"::"Service.ContractQuote.MakeContract");
            Request := Fixture.Request(Header, TypeValue in ["Message Type ori"::"Service.ContractQuote.MakeContract", "Message Type ori"::"Service.Contract.Sign"]);
            Commit();
            Clear(Runner);
            Runner.SetRequest(TypeValue, Request);
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
            Header.Get(Header."Contract Type", Header."Contract No.");
            Assert.AreEqual(Header.Status::" ", Header.Status, 'Denied operation left status unchanged.');
            Assert.AreEqual(Header."Change Status"::Open, Header."Change Status", 'Denied operation left change status unchanged.');
            Fixture.Cleanup();
        end;
    end;
}
