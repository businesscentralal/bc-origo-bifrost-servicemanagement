namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;
using System.Environment;
using System.TestLibraries.Utilities;

/// <summary>Proves posting and preview refuse an ordinary company without consent, without writing licence state.</summary>
codeunit 97747 "Svc Post Licence Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC17_OrdinaryCompany_RequiresEula()
    var
        Company: Record Company;
        Result: Record "Svc Licence Result Tst ori";
        ResponseText: Text;
        Responses: JsonObject;
        Response: JsonToken;
        ErrorCode: JsonToken;
        CompanyName: Text[30];
        SessionId: Integer;
        Attempts: Integer;
        Finished: Boolean;
        Started: Boolean;
        Input: InStream;
    begin
        // Story #7 AC17 | Time: actual session time; WorkDate ignored | Risk: shared Foundation consent gate.: actual ordinary company, not a spoofed platform flag or mutated consent setup.
        CompanyName := CopyStr('X-SVC-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 30);
        Company.Init();
        Company.Name := CompanyName;
        Company.Insert(true);
        Result.Id := CreateGuid();
        Result.Insert();
        Commit();
        Started := StartSession(SessionId, Codeunit::"Svc Post Licence Probe ori", CompanyName, Result);
        if Started then
            repeat
                Sleep(500);
                Result.Get(Result.Id);
                Finished := Result.Completed;
                Attempts += 1;
            until Finished or (Attempts >= 120);
        if Started and not Finished then
            StopSession(SessionId);
        if Finished then begin
            Result.CalcFields(Response);
            Result.Response.CreateInStream(Input, TextEncoding::UTF8);
            Input.ReadText(ResponseText);
        end;
        Result.Delete();
        Company.Get(CompanyName);
        Company.Delete();
        Commit();
        Assert.IsTrue(Started and Finished, 'Owned licence probe must finish and return a response.');
        Responses.ReadFrom(ResponseText);
        Responses.Get('post', Response);
        Response.AsObject().Get('code', ErrorCode);
        Assert.AreEqual('EULA_REQUIRED', ErrorCode.AsValue().AsText(), 'Post must refuse consent before order lookup.');
        Responses.Get('preview', Response);
        Response.AsObject().Get('code', ErrorCode);
        Assert.AreEqual('EULA_REQUIRED', ErrorCode.AsValue().AsText(), 'Preview must refuse consent before order lookup.');
    end;
}
