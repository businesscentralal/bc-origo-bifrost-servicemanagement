namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Keeps loaner state changes on the dedicated lending and receipt operations, even with force.</summary>
codeunit 10076109 "Svc Loaner Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictLoaner(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    var
        Line: Record "Service Item Line";
    begin
        if (TableNo = Database::"Service Item Line") and (FieldNo = Line.FieldNo("Loaner No.")) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure LoanerHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        Line: Record "Service Item Line";
        HintLbl: Label 'Use Service.Loaner.Lend / Service.Loaner.Receive', Comment = 'is-IS=Notaðu Service.Loaner.Lend / Service.Loaner.Receive';
    begin
        if (TableNo = Database::"Service Item Line") and (FieldNo = Line.FieldNo("Loaner No.")) then
            Hint := HintLbl;
    end;
}
