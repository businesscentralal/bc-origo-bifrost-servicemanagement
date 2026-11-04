namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Posts a service order and previews its posting through the standard Business Central service posting.</summary>
enumextension 10076077 "Svc Post MsgType ori" extends "Message Type ori"
{
    value(10076079; "Service.Order.Post")
    {
        Caption = 'Service.Order.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Order Post Impl ori", "Msg Discovery ori" = "Svc Order Post Impl ori", "Msg Contract ori" = "Svc Order Post Impl ori", "Msg Confirm ori" = "Svc Post Confirm ori";
    }
    value(10076081; "Service.Order.PreviewPost")
    {
        Caption = 'Service.Order.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Order Preview Impl ori", "Msg Discovery ori" = "Svc Order Preview Impl ori", "Msg Contract ori" = "Svc Order Preview Impl ori";
    }
}
