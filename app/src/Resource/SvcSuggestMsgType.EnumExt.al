namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Qualified and available resources for a service item line.</summary>
enumextension 10076130 "Svc Suggest MsgType ori" extends "Message Type ori"
{
    value(10076131; "Service.Resource.Suggest")
    {
        Caption = 'Service.Resource.Suggest', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Resource Suggest Impl ori",
                          "Msg Discovery ori" = "Svc Resource Suggest Impl ori",
                          "Msg Contract ori" = "Svc Resource Suggest Impl ori";
    }
}
