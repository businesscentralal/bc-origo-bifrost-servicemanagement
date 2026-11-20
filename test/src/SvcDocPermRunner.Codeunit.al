namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;

/// <summary>Isolates dispatcher permission errors for callers without Foundation access.</summary>
codeunit 97761 "Svc Doc Perm Runner ori"
{
    trigger OnRun()
    var
        Data: Codeunit "Svc Test Data ori";
    begin
        Response := Data.Invoke(MessageType, Request, '', 1033, false);
    end;

    var
        MessageType: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;

    /// <summary>Sets the request under test.</summary>
    procedure SetRequest(TypeValue: Enum "Message Type ori"; RequestValue: JsonObject)
    begin
        MessageType := TypeValue;
        Request := RequestValue;
    end;

    /// <summary>Returns a successful dispatcher response, including structured refusals.</summary>
    procedure GetResponse(): JsonObject
    begin
        exit(Response);
    end;
}
