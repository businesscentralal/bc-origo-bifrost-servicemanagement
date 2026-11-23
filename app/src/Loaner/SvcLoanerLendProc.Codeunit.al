namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.Loaner;
using Origo.Bifrost;

/// <summary>Lends an available loaner through native field validation inside a rollback boundary.</summary>
codeunit 10076108 "Svc Loaner Lend Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Line: Record "Service Item Line";
        Loaner: Record Loaner;
        Entry: Record "Loaner Entry";
        Response: JsonObject;
    begin
        Entry.LockTable();
        if not Resolve(Rec, Line, Loaner) then
            exit;
        Line.Validate("Loaner No.", Loaner."No.");
        Line.Modify(true);
        Entry.SetRange("Loaner No.", Loaner."No.");
        Entry.SetRange("Document Type", Entry."Document Type"::Order);
        Entry.SetRange("Document No.", Line."Document No.");
        Entry.SetRange("Service Item Line No.", Line."Line No.");
        Entry.SetRange(Lent, true);
        Entry.FindFirst();
        Response.Add('status', 'Success');
        Response.Add('loanerNo', Loaner."No.");
        Response.Add('loanerEntryNo', Entry."Entry No.");
        Response.Add('documentType', 'Order');
        Response.Add('documentNo', Line."Document No.");
        Response.Add('serviceItemLineNo', Line."Line No.");
        Response.Add('systemId', Format(Line.SystemId, 0, 4));
        Response.Add('dateLent', Entry."Date Lent");
        Response.Add('timeLent', Entry."Time Lent");
        Response.Add('lent', true);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    var
        Parser: Codeunit "Svc Doc Request ori";
        PermissionLbl: Label 'You cannot lend or receive loaners. Ask an administrator for full Bifrost access and permission to update service data.', Comment = 'is-IS=Þú hefur ekki heimild til að lána eða taka við lánstækjum. Biddu kerfisstjóra um fullan aðgang að Bifröst og heimild til að uppfæra þjónustugögn.';
        MissingLbl: Label 'Send loanerNo and either documentNo with serviceItemLineNo, or the service item line systemId.', Comment = 'is-IS=Sendu loanerNo og annaðhvort documentNo með serviceItemLineNo eða systemId þjónustuvörulínunnar.';
        FindLbl: Label 'The loaner or service order line was not found. Read the available loaners and order lines with Data.Records.Get and retry.', Comment = 'is-IS=Lánstækið eða þjónustupöntunarlínan fannst ekki. Lestu tiltæk lánstæki og pöntunarlínur með Data.Records.Get og reyndu aftur.';
        GuidLbl: Label 'Send systemId as a nonempty service item line GUID.', Comment = 'is-IS=Sendu systemId sem gilt GUID þjónustuvörulínu sem er ekki tómt.';
        ConflictLbl: Label 'The identifiers name different service item lines. Send identifiers for the same order line.', Comment = 'is-IS=Auðkennin vísa á mismunandi þjónustuvörulínur. Sendu auðkenni fyrir sömu pöntunarlínu.';
        StateLbl: Label 'The loaner is blocked or already lent, or the line already has a loaner. Choose an available loaner and receive any existing loan with Service.Loaner.Receive first.', Comment = 'is-IS=Lánstækið er lokað eða þegar í útláni, eða línan hefur þegar lánstæki. Veldu tiltækt lánstæki og taktu fyrst við því sem er í útláni með Service.Loaner.Receive.';
        OrderLbl: Label 'Loaners can only be lent here on service order item lines. Choose a service order line.', Comment = 'is-IS=Aðeins er hægt að lána lánstæki hér á þjónustupöntunarlínum. Veldu þjónustupöntunarlínu.';
        NativeLbl: Label 'Correct the Business Central error and retry lending the loaner. Nothing was changed.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur að lána lánstækið. Engu var breytt.';

    /// <summary>Checks licensing and the write gate and preserves Omit Commit transaction semantics.</summary>
    internal procedure Dispatch(var Argument: Record "Message Argument ori")
    var
        Gate: Record "Svc Write Gate ori";
        WriteCheck: Codeunit "Svc Write Check ori";
        Processor: Codeunit "Svc Loaner Lend Proc ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Gate.WritePermission() then begin
            Parser.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        WriteCheck.AssertCanWrite('Service.Loaner.Lend');
        Argument.SetErrorContext('', '', NativeLbl);
        ClearLastError();
        if Argument."Omit Commit" then
            Processor.Run(Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Loaner Lend Proc ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
    end;

    local procedure Resolve(var Argument: Record "Message Argument ori"; var Line: Record "Service Item Line"; var Loaner: Record Loaner): Boolean
    var
        Header: Record "Service Header";
        Request: JsonObject;
        DocumentNo: Text;
        LoanerNo: Text;
        IdText: Text;
        LineNo: Integer;
        Id: Guid;
    begin
        if not Parser.CheckKeys(Argument, 'documentNo,serviceItemLineNo,systemId,loanerNo') then
            exit(false);
        Request := Argument.GetRequestJson();
        if not Parser.ReadText(Argument, Request, 'documentNo', 20, DocumentNo) then
            exit(false);
        if not Parser.ReadText(Argument, Request, 'loanerNo', 20, LoanerNo) then
            exit(false);
        if not Parser.ReadText(Argument, Request, 'systemId', 50, IdText) then
            exit(false);
        if not Parser.ReadPositiveInteger(Argument, Request, 'serviceItemLineNo', LineNo) then
            exit(false);
        if (LoanerNo = '') or ((DocumentNo <> '') xor (LineNo <> 0)) or ((DocumentNo = '') and (IdText = '')) then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, '', MissingLbl));
        Line.ReadIsolation := IsolationLevel::UpdLock;
        if IdText <> '' then begin
            if not Evaluate(Id, IdText, 9) or IsNullGuid(Id) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'systemId', GuidLbl));
            if not Line.GetBySystemId(Id) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'systemId', FindLbl));
            if (DocumentNo <> '') and ((Line."Document No." <> UpperCase(DocumentNo)) or (Line."Line No." <> LineNo)) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'systemId', ConflictLbl));
        end else
            if not Line.Get(Line."Document Type"::Order, DocumentNo, LineNo) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'documentNo', FindLbl));
        if Line."Document Type" <> Line."Document Type"::Order then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'systemId', OrderLbl));
        Header.SetLoadFields("Document Type", "No.");
        if not Header.Get(Header."Document Type"::Order, Line."Document No.") then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'documentNo', FindLbl));
        Loaner.ReadIsolation := IsolationLevel::UpdLock;
        if not Loaner.Get(LoanerNo) then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'loanerNo', FindLbl));
        Loaner.CalcFields(Lent);
        if Loaner.Blocked or Loaner.Lent or (Line."Loaner No." <> '') then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'loanerNo', StateLbl));
        exit(true);
    end;
}
