namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Runs standard BC service release/reopen inside the caller's transaction or an isolated rollback boundary.</summary>
codeunit 10076044 "Svc Release Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Header: Record "Service Header";
        Lookup: Codeunit "Svc Document Lookup ori";
        ReleaseDocument: Codeunit "Release Service Document";
        BeforeStatus: Text;
        Response: JsonObject;
    begin
        if not Lookup.FindDocument(Rec, Enum::"Service Document Type"::Order, Header) then
            exit;
        // Lookup resets filters/isolation. Re-read under the write lock and recheck state at the mutation boundary.
        Header.ReadIsolation := IsolationLevel::UpdLock;
        Header.Get(Header."Document Type", Header."No.");
        if AlreadyAtTarget(Rec, Header) then
            exit;
        BeforeStatus := StatusName(Header);
        if Rec.Type = Rec.Type::"Service.Order.Release" then
            ReleaseDocument.PerformManualRelease(Header)
        else
            ReleaseDocument.PerformManualReopen(Header);
        Header.Get(Header."Document Type", Header."No.");
        Header.CalcFields(Amount, "Amount Including VAT");
        Response.Add('status', 'Success');
        Response.Add('documentType', 'Order');
        Response.Add('documentNo', Header."No.");
        Response.Add('systemId', Format(Header.SystemId, 0, 4));
        Response.Add('customerNo', Header."Customer No.");
        Response.Add('customerName', Header.Name);
        Response.Add('releaseStatusBefore', BeforeStatus);
        Response.Add('releaseStatusAfter', StatusName(Header));
        Response.Add('amount', Header.Amount);
        Response.Add('amountIncludingVAT', Header."Amount Including VAT");
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    var
        ReleasedLbl: Label 'Service order %1 is already released. Nothing was changed.', Comment = '%1 = order number, is-IS=Þjónustupöntun %1 hefur þegar verið gefin út. Engu var breytt.';
        ReopenLbl: Label 'To change it, use Service.Order.Reopen.', Comment = 'is-IS=Til að breyta henni, notaðu Service.Order.Reopen.';
        OpenLbl: Label 'Service order %1 is already open. Nothing to do.', Comment = '%1 = order number, is-IS=Þjónustupöntun %1 er þegar opin. Ekkert að gera.';
        NothingLbl: Label 'Nothing to do. The service order can already be changed.', Comment = 'is-IS=Ekkert að gera. Nú þegar er hægt að breyta þjónustupöntuninni.';
        AddLineLbl: Label 'Add a line with a type and a quantity with Data.Records.Set.', Comment = 'is-IS=Bættu við línu með tegund og magni með Data.Records.Set.';
        CorrectLbl: Label 'Correct the Business Central error and retry the service order operation.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aðgerðina á þjónustupöntuninni aftur.';

    /// <summary>Validates identity and state, then calls the standard BC operation without committing an Omit Commit transaction.</summary>
    internal procedure Execute(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Header";
        Line: Record "Service Line";
        Lookup: Codeunit "Svc Document Lookup ori";
        NoLines: Boolean;
        ErrorText: Text;
        Response: JsonObject;
        ErrorCode: JsonToken;
    begin
        if not Lookup.FindDocument(Argument, Enum::"Service Document Type"::Order, Header) then
            exit;
        if AlreadyAtTarget(Argument, Header) then
            exit;
        if Argument.Type = Argument.Type::"Service.Order.Release" then begin
            Line.SetLoadFields("Document Type", "Document No.", Type, Quantity);
            Line.SetRange("Document Type", Header."Document Type");
            Line.SetRange("Document No.", Header."No.");
            Line.SetFilter(Type, '<>%1', Line.Type::" ");
            Line.SetFilter(Quantity, '<>0');
            NoLines := Line.IsEmpty();
        end;

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Svc Release Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Release Proc ori", Argument) then begin
                Argument.RespondWithLastError();
                Response := Argument.GetResponseJson();
                if Response.Get('code', ErrorCode) then
                    if ErrorCode.AsValue().AsText() = 'Retryable' then
                        exit;
                // RespondWithLastError has already collected the native error. Remap that response once;
                // adding another collected error would turn this single precondition into MultipleErrors.
                if NoLines then begin
                    Response.Replace('code', 'PreconditionFailed');
                    ErrorText := AddLineLbl;
                end else
                    ErrorText := CorrectLbl;
                if Response.Contains('nextStep') then
                    Response.Replace('nextStep', ErrorText)
                else
                    Response.Add('nextStep', ErrorText);
                Argument.SetResponseJson(Response);
            end;
    end;

    local procedure AlreadyAtTarget(var Argument: Record "Message Argument ori"; Header: Record "Service Header"): Boolean
    begin
        if Argument.Type = Argument.Type::"Service.Order.Release" then begin
            if Header."Release Status" <> Header."Release Status"::"Released to Ship" then
                exit(false);
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ReleasedLbl, Header."No."), '', '', '', ReopenLbl);
        end else begin
            if Header."Release Status" <> Header."Release Status"::Open then
                exit(false);
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(OpenLbl, Header."No."), '', '', '', NothingLbl);
        end;
        exit(true);
    end;

    local procedure StatusName(Header: Record "Service Header"): Text
    begin
        if Header."Release Status" = Header."Release Status"::Open then
            exit('Open');
        exit('ReleasedToShip');
    end;
}
