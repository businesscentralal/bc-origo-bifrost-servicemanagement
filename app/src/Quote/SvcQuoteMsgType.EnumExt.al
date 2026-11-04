namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Converts an accepted service quote with native BC confirmation and conversion.</summary>
enumextension 10076050 "Svc Quote MsgType ori" extends "Message Type ori"
{
    value(10076051; "Service.Quote.MakeOrder")
    {
        Caption = 'Service.Quote.MakeOrder', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Quote MakeOrder Impl ori", "Msg Discovery ori" = "Svc Quote MakeOrder Impl ori", "Msg Contract ori" = "Svc Quote MakeOrder Impl ori", "Msg Confirm ori" = "Svc Confirm ori";
    }
}
