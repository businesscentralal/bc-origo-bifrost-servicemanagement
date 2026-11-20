namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Undoes posted service shipment and consumption lines through the standard Business Central undo.</summary>
enumextension 10076087 "Svc Undo MsgType ori" extends "Message Type ori"
{
    value(10076088; "Service.Shipment.Undo")
    {
        Caption = 'Service.Shipment.Undo', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Shipment Undo Impl ori", "Msg Discovery ori" = "Svc Shipment Undo Impl ori", "Msg Contract ori" = "Svc Shipment Undo Impl ori", "Msg Confirm ori" = "Svc Undo Confirm ori";
    }
    value(10076090; "Service.Consumption.Undo")
    {
        Caption = 'Service.Consumption.Undo', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Consumption Undo Impl ori", "Msg Discovery ori" = "Svc Consumption Undo Impl ori", "Msg Contract ori" = "Svc Consumption Undo Impl ori", "Msg Confirm ori" = "Svc Undo Confirm ori";
    }
}
