namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Exposes receiving a lent loaner through standard Business Central operations.</summary>
enumextension 10076104 "Svc Loaner MsgType ori" extends "Message Type ori"
{
    value(10076105; "Service.Loaner.Receive")
    {
        Caption = 'Service.Loaner.Receive', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Loaner Receive Impl ori", "Msg Discovery ori" = "Svc Loaner Receive Impl ori", "Msg Contract ori" = "Svc Loaner Receive Impl ori";
    }
    value(10076107; "Service.Loaner.Lend")
    {
        Caption = 'Service.Loaner.Lend', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Loaner Lend Impl ori", "Msg Discovery ori" = "Svc Loaner Lend Impl ori", "Msg Contract ori" = "Svc Loaner Lend Impl ori";
    }
}
