namespace Origo.Bifrost.ServiceManagement.Verification;

using Microsoft.Service.Document;
using Origo.Bifrost.ServiceManagement.Test;

/// <summary>Seeds isolated worker-owned quote fixtures without consent or licence writes.</summary>
codeunit 97790 "Svc5 MCP Seed ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    /// <summary>Creates the unique own quotes once; subsequent recovery retains existing markers.</summary>
    [Test]
    procedure SeedOwnedQuoteFixtures()
    var
        Header: Record "Service Header";
        Data: Codeunit "Svc Test Data ori";
        Languages: List of [Integer];
        LanguageId: Integer;
        ScenarioId: Integer;
    begin
        Data.ConfigureMcpWriteLogging();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            for ScenarioId := 1 to 3 do begin
                Header.Reset();
                Header.SetRange(Description, 'Dainn worker7 issue5 MCP ' + Format(LanguageId, 0, 9) + '/' + Format(ScenarioId, 0, 9));
                if Header.IsEmpty() then begin
                    Clear(Header);
                    Data.CreateDocument(Header, Header."Document Type"::Quote);
                    Header.Description := CopyStr('Dainn worker7 issue5 MCP ' + Format(LanguageId, 0, 9) + '/' + Format(ScenarioId, 0, 9), 1, MaxStrLen(Header.Description));
                    if ScenarioId = 2 then
                        Header."Customer No." := '';
                    if ScenarioId = 3 then
                        Header."Bill-to Customer No." := '';
                    Header.Modify();
                end;
            end;
        end;
        Commit();
    end;
}
