namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;

/// <summary>Invokes posting and preview in a new ordinary company without accepting EULA or activating a trial.</summary>
codeunit 97748 "Svc Post Licence Probe ori"
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
        Request.Add('expectedCount', 1);
        ResponseJson := Data.Invoke("Message Type ori"::"Service.Order.Post", Request, '', 1033, false);
        Responses.Add('post', ResponseJson);
        Clear(Request);
        Request.Add('no', 'X-NOT-NEEDED');
        ResponseJson := Data.Invoke("Message Type ori"::"Service.Order.PreviewPost", Request, '', 1039, false);
        Responses.Add('preview', ResponseJson);
        Responses.WriteTo(ResultText);
        Rec.Get(Rec.Id);
        Rec.Response.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(ResultText);
        Rec.Completed := true;
        Rec.Modify();
    end;
}
