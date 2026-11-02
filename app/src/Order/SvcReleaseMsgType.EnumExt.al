namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Service order warehouse-release operations.</summary>
enumextension 10076039 "Svc Release MsgType ori" extends "Message Type ori"
{
    value(10076042; "Service.Order.Release")
    {
        Caption = 'Service.Order.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Order Release Impl ori", "Msg Discovery ori" = "Svc Order Release Impl ori", "Msg Contract ori" = "Svc Order Release Impl ori";
    }
    value(10076043; "Service.Order.Reopen")
    {
        Caption = 'Service.Order.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Order Reopen Impl ori", "Msg Discovery ori" = "Svc Order Reopen Impl ori", "Msg Contract ori" = "Svc Order Reopen Impl ori";
    }
}
