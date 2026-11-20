namespace Origo.Bifrost.ServiceManagement.Test;

/// <summary>Runs one undo request in its own error boundary so a permission test can read either a JSON refusal or a platform denial.</summary>
codeunit 97755 "Svc Undo Perm Runner ori"
{
    trigger OnRun()
    var
        UndoData: Codeunit "Svc Undo Data ori";
    begin
        Response := UndoData.UndoLine(Consumption, ShipmentNo, LineNo);
    end;

    var
        Response: JsonObject;
        ShipmentNo: Code[20];
        LineNo: Integer;
        Consumption: Boolean;

    /// <summary>Sets the request to run.</summary>
    /// <param name="NewConsumption">True for consumption undo.</param>
    /// <param name="NewShipmentNo">The posted shipment.</param>
    /// <param name="NewLineNo">The line.</param>
    procedure SetRequest(NewConsumption: Boolean; NewShipmentNo: Code[20]; NewLineNo: Integer)
    begin
        Consumption := NewConsumption;
        ShipmentNo := NewShipmentNo;
        LineNo := NewLineNo;
    end;

    /// <summary>Returns the answer of the last run.</summary>
    /// <returns>The answer.</returns>
    procedure GetResponse(): JsonObject
    begin
        exit(Response);
    end;
}
