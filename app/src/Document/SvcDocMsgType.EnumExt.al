namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Standalone service billing and posting operations.</summary>
enumextension 10076103 "Svc Doc MsgType ori" extends "Message Type ori"
{
    value(10076094; "Service.Document.Post")
    {
        Caption = 'Service.Document.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Doc Post Impl ori", "Msg Discovery ori" = "Svc Doc Post Impl ori", "Msg Contract ori" = "Svc Doc Post Impl ori", "Msg Confirm ori" = "Svc Doc Confirm ori";
    }
    value(10076096; "Service.Document.PreviewPost")
    {
        Caption = 'Service.Document.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Doc Preview Impl ori", "Msg Discovery ori" = "Svc Doc Preview Impl ori", "Msg Contract ori" = "Svc Doc Preview Impl ori";
    }
    value(10076101; "Service.Invoice.GetShipmentLines")
    {
        Caption = 'Service.Invoice.GetShipmentLines', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Inv Shipment Impl ori", "Msg Discovery ori" = "Svc Inv Shipment Impl ori", "Msg Contract ori" = "Svc Inv Shipment Impl ori";
    }
}
