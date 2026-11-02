namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Protects only Release Status from generic writes while leaving ordinary service edits and reads available.</summary>
codeunit 10076045 "Svc Release Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictReleaseStatus(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    var
        Header: Record "Service Header";
    begin
        if (TableNo = Database::"Service Header") and (FieldNo = Header.FieldNo("Release Status")) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure ReleaseStatusHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        Header: Record "Service Header";
        HintLbl: Label 'Use Service.Order.Release / Service.Order.Reopen', Comment = 'is-IS=Notaðu Service.Order.Release / Service.Order.Reopen';
    begin
        if (TableNo = Database::"Service Header") and (FieldNo = Header.FieldNo("Release Status")) then
            Hint := HintLbl;
    end;
}
