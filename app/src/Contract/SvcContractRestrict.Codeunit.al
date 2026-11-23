namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Directs generic change-status writes to the dedicated lifecycle operations.</summary>
codeunit 10076158 "Svc Contract Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictChangeStatus(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    var
        Header: Record "Service Contract Header";
    begin
        if (TableNo = Database::"Service Contract Header") and (FieldNo = Header.FieldNo("Change Status")) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure ChangeStatusHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        Header: Record "Service Contract Header";
        HintLbl: Label 'Use Service.Contract.Lock / Service.Contract.Unlock.', Comment = 'is-IS=Notaðu Service.Contract.Lock / Service.Contract.Unlock.';
    begin
        if (TableNo = Database::"Service Contract Header") and (FieldNo = Header.FieldNo("Change Status")) then
            Hint := HintLbl;
    end;
}
