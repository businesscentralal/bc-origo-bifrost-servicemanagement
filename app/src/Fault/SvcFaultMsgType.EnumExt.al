namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Fault reporting reads: resolution codes that fixed the same fault before.</summary>
enumextension 10076121 "Svc Fault MsgType ori" extends "Message Type ori"
{
    value(10076120; "Service.FaultResolution.Suggest")
    {
        Caption = 'Service.FaultResolution.Suggest', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Fault Resol Suggest ori", "Msg Discovery ori" = "Svc Fault Resol Suggest ori", "Msg Contract ori" = "Svc Fault Resol Suggest ori";
    }
}
