namespace Origo.Bifrost.ServiceManagement.Test;

using System.TestTools.TestRunner;

/// <summary>
/// Registers the Bifrost Service Management test codeunits in their own AL Test Suite so a test
/// run can select them without touching the shared DEFAULT suite of the container, where a dozen
/// Bifröst and Cloud Events test apps are installed side by side.
/// </summary>
codeunit 97700 "Svc Test Install ori"
{
    Subtype = Install;

    var
        SuiteNameTok: Label 'SERVICEMGT', Locked = true;
        ObjectRangeTok: Label '97700..97699', Locked = true;

    trigger OnInstallAppPerCompany()
    begin
        RefreshTestSuite();
    end;

    /// <summary>Rebuilds this app's own suite from its own object range. Safe to call repeatedly.</summary>
    internal procedure RefreshTestSuite()
    var
        ALTestSuite: Record "AL Test Suite";
        TestMethodLine: Record "Test Method Line";
        TestSuiteMgt: Codeunit "Test Suite Mgt.";
        SuiteName: Code[10];
    begin
        SuiteName := CopyStr(SuiteNameTok, 1, MaxStrLen(SuiteName));
        if not ALTestSuite.Get(SuiteName) then begin
            TestSuiteMgt.CreateTestSuite(SuiteName);
            Commit();
            ALTestSuite.Get(SuiteName);
        end;

        TestMethodLine.SetRange("Test Suite", ALTestSuite.Name);
        TestMethodLine.SetFilter("Test Codeunit", ObjectRangeTok);
        if not TestMethodLine.IsEmpty() then
            TestMethodLine.DeleteAll(true);

        TestSuiteMgt.SelectTestMethodsByRange(ALTestSuite, ObjectRangeTok);
    end;
}
