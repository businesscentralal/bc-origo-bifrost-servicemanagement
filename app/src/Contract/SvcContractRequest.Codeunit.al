namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Validates contract identity and caller decisions before any native writes.</summary>
codeunit 10076156 "Svc Contract Request ori"
{
    Access = Internal;

    var
        IdentityLbl: Label 'Send contractNo (contractQuoteNo for a quote), systemId or a plain subject identifying one service contract.', Comment = 'is-IS=Sendu contractNo (contractQuoteNo fyrir tilboð), systemId eða númer í subject sem auðkennir einn þjónustusamning.';
        FormatLbl: Label '%1 has an invalid format.', Comment = '%1 = parameter, is-IS=%1 er á ógildu sniði.';
        MissingLbl: Label 'A service contract identifier is required.', Comment = 'is-IS=Auðkenni þjónustusamnings vantar.';
        ConflictLbl: Label 'The identifiers refer to different service contracts.', Comment = 'is-IS=Auðkennin vísa í mismunandi þjónustusamninga.';
        NotFoundLbl: Label 'The service contract or quote was not found.', Comment = 'is-IS=Þjónustusamningurinn eða tilboðið fannst ekki.';
        WrongScopeLbl: Label 'The identifier refers to the wrong kind of service contract document.', Comment = 'is-IS=Auðkennið vísar í ranga tegund þjónustusamningsskjals.';
        FlagLbl: Label 'Send true or false as a JSON boolean.', Comment = 'is-IS=Sendu true eða false sem JSON-rökgildi.';
        ConfirmLbl: Label 'Confirm the operation on one service contract by sending expectedCount: 1.', Comment = 'is-IS=Staðfestu aðgerðina á einum þjónustusamningi með því að senda expectedCount: 1.';
        CountLbl: Label 'The expected count does not match the one selected service contract.', Comment = 'is-IS=Áætlaður fjöldi samsvarar ekki einum völdum þjónustusamningi.';

    /// <summary>Resolves every supplied identifier, with exact document scope and no truncation.</summary>
    internal procedure Find(var Argument: Record "Message Argument ori"; var Header: Record "Service Contract Header"): Boolean
    var
        Request: JsonObject;
        Number: Text;
        SubjectNumber: Text;
        IdText: Text;
        KeyName: Text;
        Id: Guid;
        ContractType: Enum "Service Contract Type";
    begin
        Request := Argument.GetRequestJson();
        ContractType := ContractType::Contract;
        KeyName := 'contractNo';
        if Argument.Type = Argument.Type::"Service.ContractQuote.MakeContract" then begin
            ContractType := ContractType::Quote;
            KeyName := 'contractQuoteNo';
        end;
        if not ReadText(Argument, Request, KeyName, 20, Number) then
            exit(false);
        if not ReadText(Argument, Request, 'systemId', 50, IdText) then
            exit(false);
        SubjectNumber := Argument.Subject.Trim();
        if StrLen(SubjectNumber) > 20 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'subject'), 'subject'));
        if (Number = '') and (IdText = '') and (SubjectNumber = '') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, KeyName));
        if (Number <> '') and (SubjectNumber <> '') and (UpperCase(Number) <> UpperCase(SubjectNumber)) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, KeyName));
        if Number = '' then
            Number := SubjectNumber;
        Header.Reset();
        // Full record: the native lifecycle updates this header and its related records.
        if IdText <> '' then begin
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'systemId'), 'systemId'));
            if not Header.GetBySystemId(Id) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'systemId'));
            if (Number <> '') and (Header."Contract No." <> UpperCase(Number)) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'systemId'));
            if Header."Contract Type" <> ContractType then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, WrongScopeLbl, 'systemId'));
        end else
            if not Header.Get(ContractType, Number) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, KeyName));
        exit(true);
    end;

    /// <summary>Reads strict booleans; omitted choices use the native yes defaults.</summary>
    internal procedure BooleanValue(var Argument: Record "Message Argument ori"; Name: Text; var Value: Boolean): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Raw: Text;
    begin
        Value := true;
        Request := Argument.GetRequestJson();
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if (Raw <> 'true') and (Raw <> 'false') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name, '', 'boolean', FlagLbl);
            exit(false);
        end;
        Value := Raw = 'true';
        exit(true);
    end;

    /// <summary>Enforces the explicit single-contract confirmation approved for this lifecycle.</summary>
    internal procedure Confirm(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Response: JsonObject;
        Raw: Text;
        Count: Integer;
    begin
        if not (Argument.Type in [Argument.Type::"Service.ContractQuote.MakeContract", Argument.Type::"Service.Contract.Sign"]) then
            exit(true);
        Request := Argument.GetRequestJson();
        if not Request.Get('expectedCount', Token) then
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationRequired, ConfirmLbl, 'expectedCount', '', '1', ConfirmLbl)
        else begin
            Token.WriteTo(Raw);
            if not Evaluate(Count, Raw, 9) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'expectedCount'), 'expectedCount'));
            if Count = 1 then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationMismatch, CountLbl, 'expectedCount', Raw, '1', ConfirmLbl);
        end;
        Response := Argument.GetResponseJson();
        Response.Add('count', 1);
        Argument.SetResponseJson(Response);
        exit(false);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; Maximum: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name));
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name));
        exit(true);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Reason: Text; Parameter: Text): Boolean
    begin
        Argument.RespondWithError(Code, Reason, Parameter, '', '', IdentityLbl);
        exit(false);
    end;
}
