namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;

/// <summary>Invokes both service-order types in a new ordinary company without accepting EULA or activating a trial.</summary>
codeunit 97714 "Svc Licence Probe Tst ori"
{
    TableNo = "Svc Licence Result Tst ori";

    trigger OnRun()
    var
        Data: Codeunit "Svc Test Data ori";
        Request: JsonObject;
        ResponseJson: JsonObject;
        Responses: JsonObject;
        ResultText: Text;
        Output: OutStream;
    begin
        Request.Add('no', 'X-NOT-NEEDED');
        ResponseJson := Data.Invoke("Message Type ori"::"Service.Order.Release", Request, '', 1033, false);
        Responses.Add('release', ResponseJson);
        Clear(Request);
        Request.Add('no', 'X-NOT-NEEDED');
        ResponseJson := Data.Invoke("Message Type ori"::"Service.Order.Reopen", Request, '', 1033, false);
        Responses.Add('reopen', ResponseJson);
        Responses.WriteTo(ResultText);
        Rec.Get(Rec.Id);
        Rec.Response.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(ResultText);
        Rec.Completed := true;
        Rec.Modify();
    end;
}
