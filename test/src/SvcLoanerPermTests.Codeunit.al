namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.Loaner;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Checks posting-token, read-role and no-permission refusals for standalone billing.</summary>
codeunit 97764 "Svc Loaner Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Svc Loaner Data ori";
        Data: Codeunit "Svc Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC04_ReadRole_AllOperationsRefused()
    begin
        // Story #26 AC04 | Time: WorkDate | Risk: native broad execute must not bypass write gate.
        CheckDenied('BIFROST Read ori', false);
        CheckDenied('BIFROST Read ori', true);
    end;

    [Test]
    [HandlerFunctions('ConfirmLoaner')]
    procedure Scenario_AC04_NoPermission_AllOperationsRefused()
    begin
        // Story #26 AC04 | Time: WorkDate | Risk: no access to Foundation or service records.
        CheckDenied('Svc NoGrant Tst ori', false);
        CheckDenied('Svc NoGrant Tst ori', true);
    end;

    local procedure CheckDenied(RoleName: Code[20]; Lending: Boolean)
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Runner: Codeunit "Svc Doc Perm Runner ori";
        Request: JsonObject;
        Response: JsonObject;
        Failure: Text;
        Ran: Boolean;
    begin
        Fixture.Create(Line, Loaner);
        Commit();
        Response := Fixture.Lend(Line, Loaner."No.", 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Fixture lent.');
        Request := Fixture.Request(Line);
        if Lending then begin
            Request.Add('loanerNo', Loaner."No.");
            Runner.SetRequest("Message Type ori"::"Service.Loaner.Lend", Request);
        end else
            Runner.SetRequest("Message Type ori"::"Service.Loaner.Receive", Request);
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
        Loaner.CalcFields(Lent);
        Assert.IsTrue(Loaner.Lent, 'Denied caller cannot close the loan.');
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(Loaner."No.", Line."Loaner No.", 'Denied caller cannot clear the line.');
        Fixture.Cleanup();
    end;
    /// <summary>Answers the native loaner confirmation in the interactive AL test runner.</summary>
    [ConfirmHandler]
    procedure ConfirmLoaner(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.IsTrue(LowerCase(Question).Contains('loaner') or LowerCase(Question).Contains('lánst'), Question);
        Reply := true;
    end;
}
