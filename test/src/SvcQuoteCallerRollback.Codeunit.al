namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Runs conversion with Omit Commit, then fails after an unrelated caller write.</summary>
codeunit 97720 "Svc Quote Caller Rollback ori"
{
    TableNo = "Service Header";

    trigger OnRun()
    var
        Header: Record "Service Header";
        Data: Codeunit "Svc Test Data ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('no', Rec."No.");
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Quote.MakeOrder", Request, '', 1033, true);
        if Data.TextValue(Response, 'status') <> 'Success' then
            Error('Conversion must succeed before testing caller rollback.');
        Header.Get(Header."Document Type"::Order, Data.TextValue(Response, 'orderNo'));
        Header.Description := 'X-CALLER-ROLLBACK';
        Header.Modify();
        Error('X-EXPECTED-CALLER-ROLLBACK');
    end;
}
