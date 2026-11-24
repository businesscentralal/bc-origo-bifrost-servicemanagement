namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Registers bounded contract periodic operations.</summary>
enumextension 10076166 "Svc Contr Jobs MsgType ori" extends "Message Type ori"
{
    /// <summary>Service.Contract.CreateInvoices.</summary>
    value(10076160; "Service.Contract.CreateInvoices")
    {
        Caption = 'Service.Contract.CreateInvoices', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contr Invoice Impl ori", "Msg Discovery ori" = "Svc Contr Invoice Impl ori", "Msg Contract ori" = "Svc Contr Invoice Impl ori";
    }
    /// <summary>Service.Contract.CreateServiceOrders.</summary>
    value(10076161; "Service.Contract.CreateServiceOrders")
    {
        Caption = 'Service.Contract.CreateServiceOrders', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contr Order Impl ori", "Msg Discovery ori" = "Svc Contr Order Impl ori", "Msg Contract ori" = "Svc Contr Order Impl ori";
    }
    /// <summary>Service.Contract.CreateCreditMemo.</summary>
    value(10076162; "Service.Contract.CreateCreditMemo")
    {
        Caption = 'Service.Contract.CreateCreditMemo', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Contr Credit Impl ori", "Msg Discovery ori" = "Svc Contr Credit Impl ori", "Msg Contract ori" = "Svc Contr Credit Impl ori";
    }
}
