namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Resolves a service document of the caller's required type without truncating identifiers.</summary>
codeunit 10076041 "Svc Document Lookup ori"
{
    Access = Internal;

    var
        MissingLbl: Label 'Send a service document no, systemId or plain subject.', Comment = 'is-IS=Sendu no eða systemId þjónustuskjals eða númer þess í subject.';
        InvalidLbl: Label '%1 must be a nonempty JSON string of at most %2 characters.', Comment = '%1 = parameter, %2 = maximum length, is-IS=%1 verður að vera JSON-strengur sem er ekki tómur og er að hámarki %2 stafir.';
        GuidLbl: Label 'systemId must be a nonempty GUID.', Comment = 'is-IS=systemId verður að vera gilt GUID sem er ekki tómt.';
        CorrectLbl: Label 'Send the identifier in the format documented by describe_message_type.', Comment = 'is-IS=Sendu auðkennið á sniðinu sem describe_message_type lýsir.';
        NotFoundLbl: Label 'Service document %1 was not found.', Comment = '%1 = identifier, is-IS=Þjónustuskjal %1 fannst ekki.';
        LookupLbl: Label 'Read service documents with Data.Records.Get (table Service Header) and send an existing identifier.', Comment = 'is-IS=Lestu þjónustuskjöl með Data.Records.Get (tafla Service Header) og sendu auðkenni sem er til.';
        WrongTypeLbl: Label 'Service document %1 is not a %2 (actual type: %3).', Comment = '%1 = document number, %2 = expected type, %3 = actual type, is-IS=Þjónustuskjal %1 er ekki af gerðinni %2 (raunveruleg gerð: %3).';
        WrongTypeNextLbl: Label 'Send the No. or SystemId of a service document of type %1.', Comment = '%1 = document type, is-IS=Sendu númer eða SystemId þjónustuskjals af gerðinni %1.';
        ConflictLbl: Label 'The identifiers do not identify the same service document.', Comment = 'is-IS=Auðkennin vísa ekki á sama þjónustuskjalið.';
        ConflictNextLbl: Label 'Send identifiers belonging to the same service document.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sama þjónustuskjalinu.';
        NothingLbl: Label 'Nothing was changed.', Comment = 'is-IS=Engu var breytt.';

    /// <summary>Validates all declared identifiers before reading the requested document. The caller chooses its document type.</summary>
    internal procedure FindDocument(var Argument: Record "Message Argument ori"; DocumentType: Enum "Service Document Type"; var ServiceHeader: Record "Service Header"): Boolean
    var
        Request: JsonObject;
        Number: Text;
        IdText: Text;
        SubjectNumber: Text;
        Id: Guid;
    begin
        Request := Argument.GetRequestJson();
        Number := ReadIdentifier(Argument, Request, 'no', MaxStrLen(ServiceHeader."No."));
        IdText := ReadIdentifier(Argument, Request, 'systemId', 50);
        SubjectNumber := Argument.Subject.Trim();
        if StrLen(SubjectNumber) > MaxStrLen(ServiceHeader."No.") then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidLbl, 'subject', MaxStrLen(ServiceHeader."No.")), 'subject', '', '', CorrectLbl);
        if (Number = '') and (IdText = '') and (SubjectNumber = '') and not Argument.HasCollectedErrors() then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingLbl, 'no/systemId', '', '', CorrectLbl);
        if IdText <> '' then
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, GuidLbl, 'systemId', IdText, 'GUID', CorrectLbl);
        if Argument.HasCollectedErrors() then begin
            Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, NothingLbl);
            exit(false);
        end;
        if (Number <> '') and (SubjectNumber <> '') and (UpperCase(Number) <> UpperCase(SubjectNumber)) then
            exit(Conflict(Argument));
        if Number = '' then
            Number := SubjectNumber;

        // Return a full record: release and posting callers modify this header through standard BC codeunits.
        ServiceHeader.Reset();
        if IdText <> '' then begin
            if not ServiceHeader.GetBySystemId(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, IdText), 'systemId', IdText, '', LookupLbl);
                exit(false);
            end;
            if ServiceHeader."Document Type" <> DocumentType then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter,
                    StrSubstNo(WrongTypeLbl, ServiceHeader."No.", TypeName(DocumentType), TypeName(ServiceHeader."Document Type")),
                    'systemId', IdText, TypeName(DocumentType), StrSubstNo(WrongTypeNextLbl, TypeName(DocumentType)));
                exit(false);
            end;
            if (Number <> '') and (ServiceHeader."No." <> UpperCase(Number)) then
                exit(Conflict(Argument));
            exit(true);
        end;
        if not ServiceHeader.Get(DocumentType, Number) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, Number), 'no', Number, '', LookupLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Returns invariant service document type names for machine-readable contracts and errors.</summary>
    internal procedure TypeName(DocumentType: Enum "Service Document Type"): Text
    begin
        case DocumentType of
            DocumentType::Quote:
                exit('Quote');
            DocumentType::Order:
                exit('Order');
            DocumentType::Invoice:
                exit('Invoice');
            DocumentType::"Credit Memo":
                exit('CreditMemo');
        end;
        exit('');
    end;

    local procedure ReadIdentifier(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Maximum: Integer): Text
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
    begin
        if not Request.Get(KeyName, Token) then
            exit('');
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, KeyName, Maximum), KeyName, '', 'string', CorrectLbl);
            exit('');
        end;
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidLbl, KeyName, Maximum), KeyName, '', '', CorrectLbl);
        exit(Value);
    end;

    local procedure Conflict(var Argument: Record "Message Argument ori"): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'no/systemId/subject', '', '', ConflictNextLbl);
        exit(false);
    end;
}
