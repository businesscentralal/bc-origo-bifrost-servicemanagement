namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Validates standalone service document requests before posting or preview.</summary>
codeunit 10076099 "Svc Doc Request ori"
{
    Access = Internal;

    /// <summary>Checks declared keys and resolves an invoice or credit memo.</summary>
    internal procedure Find(var Argument: Record "Message Argument ori"; var Header: Record "Service Header"): Boolean
    var
        Lookup: Codeunit "Svc Document Lookup ori";
        Request: JsonObject;
        DocumentType: Enum "Service Document Type";
        TypeName: Text;
        MissingLbl: Label 'Send documentType as Invoice or CreditMemo.', Comment = 'is-IS=Sendu documentType sem Invoice eða CreditMemo.';
        OrderLbl: Label 'Use Service.Order.Post or Service.Order.PreviewPost for service orders.', Comment = 'is-IS=Notaðu Service.Order.Post eða Service.Order.PreviewPost fyrir þjónustupantanir.';
    begin
        Request := Argument.GetRequestJson();
        if not CheckKeys(Argument, 'documentType,no,systemId,expectedCount') then
            exit(false);
        if not Request.Contains('documentType') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'documentType', MissingLbl));
        if not ReadText(Argument, Request, 'documentType', 20, TypeName) then
            exit(false);
        case TypeName of
            'Invoice': DocumentType := DocumentType::Invoice;
            'CreditMemo': DocumentType := DocumentType::"Credit Memo";
            'Order': exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'documentType', OrderLbl));
            else exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'documentType', MissingLbl));
        end;
        exit(Lookup.FindDocument(Argument, DocumentType, Header));
    end;

    /// <summary>Refuses undeclared request keys before any changes.</summary>
    internal procedure CheckKeys(var Argument: Record "Message Argument ori"; Allowed: Text): Boolean
    var
        Request: JsonObject;
        Keys: List of [Text];
        KeyName: Text;
        UnknownLbl: Label 'Remove the unknown parameter %1 and use the documented parameters.', Comment = '%1 = parameter, is-IS=Fjarlægðu óþekktu færibreytuna %1 og notaðu skjalfestu færibreyturnar.';
    begin
        Keys := Allowed.Split(',');
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not Keys.Contains(KeyName) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, KeyName, StrSubstNo(UnknownLbl, KeyName)));
        exit(true);
    end;

    /// <summary>Reads an optional nonempty JSON string without truncation.</summary>
    internal procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Maximum: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatLbl: Label 'Send %1 as a nonempty string of at most %2 characters.', Comment = '%1 = parameter, %2 = length, is-IS=Sendu %1 sem streng sem er ekki tómur og er að hámarki %2 stafir.';
    begin
        Value := '';
        if not Request.Get(KeyName, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, StrSubstNo(FormatLbl, KeyName, Maximum)));
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, StrSubstNo(FormatLbl, KeyName, Maximum)));
        exit(true);
    end;

    /// <summary>Returns a structured refusal with recovery guidance.</summary>
    internal procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Parameter: Text; Guidance: Text): Boolean
    begin
        Argument.RespondWithError(Code, Guidance, Parameter, '', '', Guidance);
        exit(false);
    end;
}
