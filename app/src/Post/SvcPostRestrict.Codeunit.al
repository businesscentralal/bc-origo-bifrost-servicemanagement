namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Keeps the posted-quantity fields of a service line and the posting token away from generic writes.</summary>
codeunit 10076084 "Svc Post Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictPostedQuantities(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        if (TableNo = Database::"Service Line") and IsGuardedField(FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure PostedQuantityHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        HintLbl: Label 'Use Service.Order.Post', Comment = 'is-IS=Notaðu Service.Order.Post';
    begin
        if (TableNo = Database::"Service Line") and IsGuardedField(FieldNo) then
            Hint := HintLbl;
    end;

    local procedure IsGuardedField(FieldNo: Integer): Boolean
    var
        ServiceLine: Record "Service Line";
    begin
        exit(FieldNo in [
            ServiceLine.FieldNo("Quantity Shipped"),
            ServiceLine.FieldNo("Quantity Invoiced"),
            ServiceLine.FieldNo("Quantity Consumed"),
            ServiceLine.FieldNo("Qty. Shipped (Base)"),
            ServiceLine.FieldNo("Qty. Invoiced (Base)"),
            ServiceLine.FieldNo("Qty. Consumed (Base)")]);
    end;
}
