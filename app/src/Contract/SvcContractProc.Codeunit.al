namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Runs contract conversion, signing and change-status operations inside one rollback boundary.</summary>
codeunit 10076145 "Svc Contract Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Header: Record "Service Contract Header";
        FiledHeader: Record "Filed Service Contract Header";
        Request: Codeunit "Svc Contract Request ori";
        Options: Codeunit "Svc Contract Options ori";
        SignContract: Codeunit SignServContractDoc;
        LockOpen: Codeunit "Lock-OpenServContract";
        Response: JsonObject;
        BeforeStatus: Text;
        CreateInvoice: Boolean;
    begin
        if not Request.Find(Rec, Header) then
            exit;
        Header.ReadIsolation := IsolationLevel::UpdLock;
        Header.Get(Header."Contract Type", Header."Contract No.");
        if not Check(Rec, Header, CreateInvoice) then
            exit;
        if not Request.Confirm(Rec) then
            exit;
        BeforeStatus := ChangeStatus(Header);
        Options.SetCreateInvoice(CreateInvoice);
        BindSubscription(Options);
        SignContract.SetHideDialog(true);
        case Rec.Type of
            Rec.Type::"Service.ContractQuote.MakeContract":
                SignContract.SignContractQuote(Header);
            Rec.Type::"Service.Contract.Sign":
                SignContract.SignContract(Header);
            Rec.Type::"Service.Contract.Lock":
                LockOpen.LockServContract(Header);
            Rec.Type::"Service.Contract.Unlock":
                LockOpen.OpenServContract(Header);
        end;
        UnbindSubscription(Options);
        Header.Get(Header."Contract Type"::Contract, Header."Contract No.");
        Response.Add('status', 'Success');
        Response.Add('contractNo', Header."Contract No.");
        Response.Add('systemId', Format(Header.SystemId, 0, 4));
        Response.Add('contractStatus', Header.Status.Names().Get(Header.Status.Ordinals().IndexOf(Header.Status.AsInteger())));
        Response.Add('changeStatusBefore', BeforeStatus);
        Response.Add('changeStatusAfter', ChangeStatus(Header));
        Response.Add('nextInvoiceDate', Format(Header."Next Invoice Date", 0, 9));
        Response.Add('nextInvoicePeriodStart', Format(Header."Next Invoice Period Start", 0, 9));
        Response.Add('nextInvoicePeriodEnd', Format(Header."Next Invoice Period End", 0, 9));
        Response.Add('invoiceNo', Options.GetInvoiceNo());
        if Rec.Type = Rec.Type::"Service.ContractQuote.MakeContract" then begin
            FiledHeader.ReadIsolation := IsolationLevel::ReadCommitted;
            FiledHeader.SetLoadFields("Entry No.");
            FiledHeader.SetRange("Contract Type", FiledHeader."Contract Type"::Quote);
            FiledHeader.SetRange("Contract No.", Header."Contract No.");
            FiledHeader.FindLast();
            Response.Add('filedQuoteEntryNo', FiledHeader."Entry No.");
            Response.Add('contractQuoteNo', Header."Contract No.");
        end;
        Response.Add('nextStep', NextStepLbl);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    var
        NextStepLbl: Label 'Review the contract. Use Service.Contract.Unlock / Service.Contract.Lock for changes. Review any unposted invoice before Service.Document.Post.', Comment = 'is-IS=Yfirfarðu samninginn. Notaðu Service.Contract.Unlock / Service.Contract.Lock fyrir breytingar. Yfirfarðu óbókaðan reikning áður en Service.Document.Post er notað.';
        CorrectLbl: Label 'Correct the field or setup named by Business Central and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu reitinn eða uppsetninguna sem Business Central nefnir og reyndu aftur. Engu var breytt.';
        StateLbl: Label 'The service contract is already in the requested change status.', Comment = 'is-IS=Þjónustusamningurinn er þegar í umbeðinni breytingastöðu.';
        NewLinesLbl: Label 'This signed contract has new lines. Complete the contract addendum in Business Central before locking it.', Comment = 'is-IS=Þessi undirritaði samningur er með nýjar línur. Ljúktu við viðauka samningsins í Business Central áður en honum er læst.';
        DateLbl: Label 'The contract contains a date choice that the request did not accept.', Comment = 'is-IS=Samningurinn inniheldur dagsetningarval sem beiðnin samþykkti ekki.';
        DateNextLbl: Label 'Correct the contract dates or explicitly accept the documented date choice.', Comment = 'is-IS=Leiðréttu dagsetningar samningsins eða samþykktu sérstaklega dagsetningarvalið sem lýst er í hjálpinni.';

    /// <summary>Prevalidates without writes, then catches native errors at the transaction boundary.</summary>
    internal procedure Execute(var Argument: Record "Message Argument ori")
    var
        Header: Record "Service Contract Header";
        Request: Codeunit "Svc Contract Request ori";
        CreateInvoice: Boolean;
    begin
        if not Request.Find(Argument, Header) then
            exit;
        if not Check(Argument, Header, CreateInvoice) then
            exit;
        if not Request.Confirm(Argument) then
            exit;
        Argument.SetErrorContext('', '', CorrectLbl);
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Svc Contract Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Contract Proc ori", Argument) then
                Argument.RespondWithLastError();
        Argument.ClearErrorContext();
    end;

    local procedure Check(var Argument: Record "Message Argument ori"; Header: Record "Service Contract Header"; var CreateInvoice: Boolean): Boolean
    var
        Line: Record "Service Contract Line";
        Request: Codeunit "Svc Contract Request ori";
        AcceptMissingServiceDate: Boolean;
        AcceptNonMonthEndInvoiceDate: Boolean;
        AddLinesStartingLater: Boolean;
    begin
        if ((Argument.Type = Argument.Type::"Service.Contract.Lock") and (Header."Change Status" = Header."Change Status"::Locked)) or
           ((Argument.Type = Argument.Type::"Service.Contract.Unlock") and (Header."Change Status" = Header."Change Status"::Open)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StateLbl, '', '', '', NextStepLbl);
            exit(false);
        end;
        Line.ReadIsolation := IsolationLevel::ReadCommitted;
        Line.SetLoadFields("New Line", "Next Planned Service Date", "Starting Date");
        Line.SetRange("Contract Type", Header."Contract Type");
        Line.SetRange("Contract No.", Header."Contract No.");
        if (Argument.Type in [Argument.Type::"Service.Contract.Lock", Argument.Type::"Service.Contract.Sign"]) and (Header.Status = Header.Status::Signed) then begin
            Line.SetRange("New Line", true);
            if not Line.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NewLinesLbl, '', '', '', NewLinesLbl);
                exit(false);
            end;
            Line.SetRange("New Line");
        end;
        if Argument.Type in [Argument.Type::"Service.Contract.Lock", Argument.Type::"Service.Contract.Unlock"] then
            exit(true);
        if not Request.BooleanValue(Argument, 'createInvoice', CreateInvoice) then
            exit(false);
        if not Request.BooleanValue(Argument, 'addLinesStartingLater', AddLinesStartingLater) then
            exit(false);
        if not Request.BooleanValue(Argument, 'acceptMissingServiceDate', AcceptMissingServiceDate) then
            exit(false);
        if not Request.BooleanValue(Argument, 'acceptNonMonthEndInvoiceDate', AcceptNonMonthEndInvoiceDate) then
            exit(false);
        if not AcceptMissingServiceDate then begin
            Line.SetRange("Next Planned Service Date", 0D);
            if not Line.IsEmpty() then
                exit(RefuseDate(Argument, 'acceptMissingServiceDate'));
            Line.SetRange("Next Planned Service Date");
        end;
        if not AddLinesStartingLater then begin
            Line.SetFilter("Starting Date", '>%1', Header."Starting Date");
            if not Line.IsEmpty() then
                exit(RefuseDate(Argument, 'addLinesStartingLater'));
        end;
        if not AcceptNonMonthEndInvoiceDate and not Header.Prepaid and Header.IsInvoicePeriodInTimeSegment() then
            if Header."Next Invoice Date" <> CalcDate('<CM>', Header."Next Invoice Date") then
                exit(RefuseDate(Argument, 'acceptNonMonthEndInvoiceDate'));
        exit(true);
    end;

    local procedure RefuseDate(var Argument: Record "Message Argument ori"; Parameter: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, DateLbl, Parameter, '', '', DateNextLbl);
        exit(false);
    end;

    local procedure ChangeStatus(Header: Record "Service Contract Header"): Text
    begin
        if Header."Change Status" = Header."Change Status"::Locked then
            exit('Locked');
        exit('Open');
    end;
}
