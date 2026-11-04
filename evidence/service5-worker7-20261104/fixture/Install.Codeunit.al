namespace Origo.Bifrost.ServiceManagement.Verification;

using System.TestTools.TestRunner;

/// <summary>Registers only the temporary fixture seed in a separate suite.</summary>
codeunit 97791 "Svc5 Seed Install ori"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Suite: Record "AL Test Suite";
        Methods: Record "Test Method Line";
        SuiteMgt: Codeunit "Test Suite Mgt.";
        SuiteName: Code[10];
    begin
        SuiteName := 'SVC5SEED';
        if not Suite.Get(SuiteName) then begin
            SuiteMgt.CreateTestSuite(SuiteName);
            Commit();
            Suite.Get(SuiteName);
        end;
        Methods.SetRange("Test Suite", Suite.Name);
        Methods.DeleteAll(true);
        Suite."Test Runner Id" := 130451;
        Suite.Modify(true);
        SuiteMgt.SelectTestMethodsByRange(Suite, '97790..97790');
    end;
}
