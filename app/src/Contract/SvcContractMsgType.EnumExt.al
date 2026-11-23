namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Registers service contract lifecycle operations.</summary>
enumextension 10076154 "Svc Contract MsgType ori" extends "Message Type ori"
{
    /// <summary>Service.ContractQuote.MakeContract.</summary>
    value(10076150; "Service.ContractQuote.MakeContract")
    {
        Caption = 'Service.ContractQuote.MakeContract', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contract Make Impl ori", "Msg Discovery ori" = "Svc Contract Make Impl ori", "Msg Contract ori" = "Svc Contract Make Impl ori";
    }
    /// <summary>Service.Contract.Sign.</summary>
    value(10076151; "Service.Contract.Sign")
    {
        Caption = 'Service.Contract.Sign', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contract Sign Impl ori", "Msg Discovery ori" = "Svc Contract Sign Impl ori", "Msg Contract ori" = "Svc Contract Sign Impl ori";
    }
    /// <summary>Service.Contract.Lock.</summary>
    value(10076152; "Service.Contract.Lock")
    {
        Caption = 'Service.Contract.Lock', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contract Lock Impl ori", "Msg Discovery ori" = "Svc Contract Lock Impl ori", "Msg Contract ori" = "Svc Contract Lock Impl ori";
    }
    /// <summary>Service.Contract.Unlock.</summary>
    value(10076153; "Service.Contract.Unlock")
    {
        Caption = 'Service.Contract.Unlock', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contract Unlock Impl ori", "Msg Discovery ori" = "Svc Contract Unlock Impl ori", "Msg Contract ori" = "Svc Contract Unlock Impl ori";
    }
}
