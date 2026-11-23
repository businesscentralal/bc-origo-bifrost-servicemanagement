namespace Origo.Bifrost.ServiceManagement.Test;

using Microsoft.Service.Document;
using Microsoft.Service.Loaner;

/// <summary>Injects a native failure after a write to prove receipt rollback, only when explicitly bound.</summary>
codeunit 97766 "Svc Loaner Failure Tst ori"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ServLoanerManagement, OnBeforeReceiveLoaner, '', false, false)]
    local procedure FailAfterWrite(var ServiceItemLine: Record "Service Item Line"; var IsHandled: Boolean)
    var
        FailureLbl: Label 'Owned loaner native failure after a write.', Locked = true;
    begin
        ServiceItemLine.Description := 'Owned rollback marker';
        ServiceItemLine.Modify();
        Error(FailureLbl);
    end;
}
