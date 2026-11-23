namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Resolves and confirms a bounded contract set before any periodic-job writes.</summary>
codeunit 10076167 "Svc Contr Job Scope ori"
{
    Access = Internal;

    var
        ScopeLbl: Label 'Select 1 to 200 service contracts and supply the required dates.', Comment = 'is-IS=Veldu 1 til 200 þjónustusamninga og gefðu upp nauðsynlegar dagsetningar.';
        FormatLbl: Label '%1 has an invalid format or range.', Comment = '%1 = parameter, is-IS=%1 er á ógildu sniði eða utan leyfilegra marka.';
        StateLbl: Label 'Every selected service contract must be signed and locked.', Comment = 'is-IS=Allir valdir þjónustusamningar verða að vera undirritaðir og læstir.';
        StateNextLbl: Label 'Sign and lock the selected contracts before running this operation.', Comment = 'is-IS=Undirritaðu og læstu völdum samningum áður en þessi aðgerð er keyrð.';
        MissingLbl: Label 'No service contracts were selected.', Comment = 'is-IS=Engir þjónustusamningar voru valdir.';
        NotFoundLbl: Label 'Service contract %1 was not found.', Comment = '%1 = contract number, is-IS=Þjónustusamningur %1 fannst ekki.';
        LargeLbl: Label 'The scope exceeds 200 service contracts.', Comment = 'is-IS=Valið nær yfir fleiri en 200 þjónustusamninga.';
        NarrowLbl: Label 'Narrow the contract list or filters to at most 200 contracts.', Comment = 'is-IS=Þrengdu samningalistann eða afmarkanirnar í að hámarki 200 samninga.';
        ConflictLbl: Label 'Use either contractNos or filters, without a subject, for a batch.', Comment = 'is-IS=Notaðu annaðhvort contractNos eða afmarkanir, án subject, fyrir keyrslu á mörgum samningum.';
        ConfirmLbl: Label 'Review the selected contracts and resend expectedCount: %1 to confirm.', Comment = '%1 = contract count, is-IS=Yfirfarðu valda samninga og sendu expectedCount: %1 aftur til að staðfesta.';
        MismatchLbl: Label 'expectedCount does not match the selected contract count.', Comment = 'is-IS=expectedCount samsvarar ekki fjölda valinna samninga.';

    /// <summary>Validates dates, identities, state and confirmation, optionally locking the selected headers.</summary>
    internal procedure Resolve(var Argument: Record "Message Argument ori"; var Contracts: List of [Code[20]]; var FromDate: Date; var ToDate: Date; LockHeaders: Boolean): Boolean
    var
        Header: Record "Service Contract Header";
        SingleRequest: Codeunit "Svc Contract Request ori";
        Request: JsonObject;
        Number: Code[20];
        Credit: Boolean;
    begin
        Clear(Contracts);
        Request := Argument.GetRequestJson();
        Credit := Argument.Type = Argument.Type::"Service.Contract.CreateCreditMemo";
        if Credit then begin
            ToDate := WorkDate();
            if not ReadDate(Argument, Request, 'creditMemoDateTo', false, ToDate) then
                exit(false);
            if ToDate > WorkDate() then
                exit(Invalid(Argument, 'creditMemoDateTo'));
            if not SingleRequest.Find(Argument, Header) then
                exit(false);
            Contracts.Add(Header."Contract No.");
        end else begin
            if Argument.Type = Argument.Type::"Service.Contract.CreateInvoices" then begin
                if not ReadDate(Argument, Request, 'postingDate', true, FromDate) then
                    exit(false);
                if not ReadDate(Argument, Request, 'invoiceToDate', true, ToDate) then
                    exit(false);
            end else begin
                if not ReadDate(Argument, Request, 'startingDate', true, FromDate) then
                    exit(false);
                if not ReadDate(Argument, Request, 'endingDate', true, ToDate) then
                    exit(false);
                if (ToDate < FromDate) or (ToDate > CalcDate('<1Y>', FromDate) - 1) then
                    exit(Invalid(Argument, 'endingDate'));
            end;
            if not FindBatch(Argument, Request, Contracts) then
                exit(false);
        end;
        // Re-read under update locks inside the processor before its first write.
        if LockHeaders then
            Header.ReadIsolation := IsolationLevel::UpdLock;
        foreach Number in Contracts do begin
            if not Header.Get(Header."Contract Type"::Contract, Number) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, Number), 'contractNos', ScopeLbl));
            if (Header.Status <> Header.Status::Signed) or (Header."Change Status" <> Header."Change Status"::Locked) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateLbl, 'contractNos', StateNextLbl));
        end;
        exit(Confirm(Argument, Contracts));
    end;

    local procedure FindBatch(var Argument: Record "Message Argument ori"; Request: JsonObject; var Contracts: List of [Code[20]]): Boolean
    var
        Header: Record "Service Contract Header";
        Token: JsonToken;
        Entry: JsonToken;
        Entries: JsonArray;
        CustomerNo: Text;
        Number: Text;
        DateTo: Date;
    begin
        if Argument.Subject <> '' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'subject', ScopeLbl));
        if Request.Get('contractNos', Token) then begin
            if Request.Contains('customerNo') or Request.Contains('nextInvoiceDateTo') then
                exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'contractNos', ScopeLbl));
            if not Token.IsArray() then
                exit(Invalid(Argument, 'contractNos'));
            Entries := Token.AsArray();
            if Entries.Count() > 200 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, LargeLbl, 'contractNos', NarrowLbl));
            foreach Entry in Entries do begin
                if not StringValue(Entry, Number) then
                    exit(Invalid(Argument, 'contractNos'));
                if (Number = '') or (StrLen(Number) > 20) then
                    exit(Invalid(Argument, 'contractNos'));
                if not Contracts.Contains(CopyStr(UpperCase(Number), 1, 20)) then
                    Contracts.Add(CopyStr(UpperCase(Number), 1, 20));
            end;
        end else begin
            if not Request.Contains('customerNo') and not Request.Contains('nextInvoiceDateTo') then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'contractNos', ScopeLbl));
            Header.ReadIsolation := IsolationLevel::ReadCommitted;
            Header.SetLoadFields("Contract No.");
            Header.SetRange("Contract Type", Header."Contract Type"::Contract);
            if Request.Get('customerNo', Token) then begin
                if not StringValue(Token, CustomerNo) then
                    exit(Invalid(Argument, 'customerNo'));
                if (CustomerNo = '') or (StrLen(CustomerNo) > 20) then
                    exit(Invalid(Argument, 'customerNo'));
                Header.SetRange("Customer No.", CustomerNo);
            end;
            if Request.Contains('nextInvoiceDateTo') then begin
                if not ReadDate(Argument, Request, 'nextInvoiceDateTo', true, DateTo) then
                    exit(false);
                Header.SetFilter("Next Invoice Date", '<>%1&<=%2', 0D, DateTo);
            end;
            if Header.FindSet() then
                repeat
                    Contracts.Add(Header."Contract No.");
                    if Contracts.Count() > 200 then
                        exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, LargeLbl, 'contractNos', NarrowLbl));
                until Header.Next() = 0;
        end;
        if Contracts.Count() = 0 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'contractNos', ScopeLbl));
        exit(true);
    end;

    local procedure Confirm(var Argument: Record "Message Argument ori"; Contracts: List of [Code[20]]): Boolean
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Selected: JsonArray;
        Number: Code[20];
        Raw: Text;
        Count: Integer;
        NextStep: Text;
    begin
        Request := Argument.GetRequestJson();
        NextStep := StrSubstNo(ConfirmLbl, Contracts.Count());
        if not Request.Get('expectedCount', Token) then
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationRequired, NextStep, 'expectedCount', '', Format(Contracts.Count(), 0, 9), NextStep)
        else begin
            Token.WriteTo(Raw);
            if not Evaluate(Count, Raw, 9) or (Count < 0) then
                exit(Invalid(Argument, 'expectedCount'));
            if Count = Contracts.Count() then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationMismatch, MismatchLbl, 'expectedCount', Raw, Format(Contracts.Count(), 0, 9), NextStep);
        end;
        foreach Number in Contracts do
            Selected.Add(Number);
        Response := Argument.GetResponseJson();
        Response.Add('count', Contracts.Count());
        Response.Add('contractNos', Selected);
        Argument.SetResponseJson(Response);
        exit(false);
    end;

    local procedure ReadDate(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; Required: Boolean; var Value: Date): Boolean
    var
        Token: JsonToken;
        TextValue: Text;
    begin
        if not Request.Get(Name, Token) then begin
            if Required then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, ScopeLbl, Name, ScopeLbl));
            exit(true);
        end;
        if not StringValue(Token, TextValue) then
            exit(Invalid(Argument, Name));
        if not Evaluate(Value, TextValue, 9) or (Value = 0D) then
            exit(Invalid(Argument, Name));
        if Format(Value, 0, 9) <> TextValue then
            exit(Invalid(Argument, Name));
        exit(true);
    end;

    local procedure StringValue(Token: JsonToken; var Value: Text): Boolean
    var
        Raw: Text;
    begin
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then
            exit(false);
        Value := Token.AsValue().AsText().Trim();
        exit(true);
    end;

    local procedure Invalid(var Argument: Record "Message Argument ori"; Name: Text): Boolean
    begin
        exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name, ScopeLbl));
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Reason: Text; Parameter: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(Code, Reason, Parameter, '', '', NextStep);
        exit(false);
    end;
}
