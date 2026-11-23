namespace Origo.Bifrost.ServiceManagement.Test;

using Origo.Bifrost;

/// <summary>Runs one Service.Order.AdjustPrice call so a platform permission error can be caught by the caller.</summary>
codeunit 97773 "Svc Price Perm Runner ori"
{
    trigger OnRun()
    var
        Data: Codeunit "Svc Test Data ori";
    begin
        Response := Data.Invoke("Message Type ori"::"Service.Order.AdjustPrice", Request, '', 1033, false);
    end;

    var
        Request: JsonObject;
        Response: JsonObject;

    /// <summary>Sets the request.</summary>
    procedure SetRequest(NewRequest: JsonObject)
    begin
        Request := NewRequest;
    end;

    /// <summary>Returns the response.</summary>
    procedure GetResponse(): JsonObject
    begin
        exit(Response);
    end;
}
