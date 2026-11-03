namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Service order resource allocation.</summary>
enumextension 10076060 "Svc Alloc MsgType ori" extends "Message Type ori"
{
    value(10076061; "Service.Allocation.Allocate")
    {
        Caption = 'Service.Allocation.Allocate', Locked = true;
        Implementation = "Msg Interface ori" = "Svc Allocation Impl ori",
                          "Msg Discovery ori" = "Svc Allocation Impl ori",
                          "Msg Contract ori" = "Svc Allocation Impl ori";
    }
}
