namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.History;
using Origo.Bifrost;

/// <summary>Undoes one posted service shipment line with Omit Commit, writes to the order and then raises a caller error, to prove the caller rollback also reverses the undo.</summary>
codeunit 97756 "Svc Undo Caller Rollback ori"
{
    TableNo = "Service Shipment Line";

    var
        Consumption: Boolean;

    /// <summary>Chooses Service.Consumption.Undo instead of Service.Shipment.Undo.</summary>
    /// <param name="Value">True for consumption undo.</param>
    procedure SetConsumption(Value: Boolean)
    begin
        Consumption := Value;
    end;

    trigger OnRun()
    var
        Header: Record "Service Header";
        UndoData: Codeunit "Svc Undo Data ori";
        PostData: Codeunit "Svc Post Data ori";
        Data: Codeunit "Svc Test Data ori";
        LineNos: List of [Integer];
        Request: JsonObject;
        Response: JsonObject;
    begin
        LineNos.Add(Rec."Line No.");
        Request := UndoData.Build(Rec."Document No.", LineNos, 1);
        if Consumption then
            Response := Data.Invoke("Message Type ori"::"Service.Consumption.Undo", Request, '', 1033, true)
        else
            Response := Data.Invoke("Message Type ori"::"Service.Shipment.Undo", Request, '', 1033, true);
        PostData.AssertSuccess(Response);
        Header.Get(Header."Document Type"::Order, Rec."Order No.");
        Header.Description := 'X-SVC20-CALLER-WRITE';
        Header.Modify();
        Error('X-SVC20-EXPECTED-CALLER-ROLLBACK');
    end;
}
