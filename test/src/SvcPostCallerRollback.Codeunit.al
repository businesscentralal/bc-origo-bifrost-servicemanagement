namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Raises a caller error after an Omit Commit post to prove native BC posting survives the caller rollback.</summary>
codeunit 97750 "Svc Post Caller Rollback ori"
{
    TableNo = "Service Header";

    trigger OnRun()
    var
        Data: Codeunit "Svc Test Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := PostData.Build(Rec."No.", 'true', '', 'true', 1);
        Response := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, true);
        PostData.AssertSuccess(Response);
        Error('X-SVC7-EXPECTED-CALLER-ROLLBACK');
    end;
}
