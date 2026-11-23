namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Service price adjustment operations.</summary>
enumextension 10076142 "Svc Price MsgType ori" extends "Message Type ori"
{
    value(10076140; "Service.Order.AdjustPrice")
    {
        Caption = 'Service.Order.AdjustPrice', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Price Adjust Impl ori", "Msg Discovery ori" = "Svc Price Adjust Impl ori", "Msg Contract ori" = "Svc Price Adjust Impl ori";
    }
}
