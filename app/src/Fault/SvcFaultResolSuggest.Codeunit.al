namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.Maintenance;
using Microsoft.Service.Setup;
using Origo.Bifrost;

/// <summary>
/// Implements Service.FaultResolution.Suggest: a read of the fault/resolution code relationships that ranks the
/// resolution codes which fixed the same fault before, filtered by the service setup's fault reporting level.
/// </summary>
codeunit 10076120 "Svc Fault Resol Suggest ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    var
        InvalidTextLbl: Label '%1 must be a nonempty JSON string of at most %2 characters.', Comment = '%1 = parameter, %2 = maximum length, is-IS=%1 verður að vera JSON-strengur sem er ekki tómur og er að hámarki %2 stafir.';
        InvalidIntegerLbl: Label '%1 must be a whole number from %2 to %3.', Comment = '%1 = parameter, %2 = minimum, %3 = maximum, is-IS=%1 verður að vera heiltala frá %2 til %3.';
        GuidLbl: Label 'systemId must be a nonempty GUID.', Comment = 'is-IS=systemId verður að vera gilt GUID sem er ekki tómt.';
        CorrectLbl: Label 'Send the value in the documented format and retry.', Comment = 'is-IS=Sendu gildið á sniðinu sem lýst er og reyndu aftur.';
        MissingLbl: Label 'Send a service item line (documentNo and serviceItemLineNo, or systemId) or the codes directly (faultCode).', Comment = 'is-IS=Sendu þjónustuvörulínu (documentNo og serviceItemLineNo, eða systemId) eða kóðana beint (faultCode).';
        MissingNextLbl: Label 'Read the service item lines with Data.Records.Get (table Service Item Line) and send documentNo and serviceItemLineNo.', Comment = 'is-IS=Lestu þjónustuvörulínurnar með Data.Records.Get (tafla Service Item Line) og sendu documentNo og serviceItemLineNo.';
        MissingDocumentLbl: Label 'serviceItemLineNo needs documentNo.', Comment = 'is-IS=serviceItemLineNo þarf documentNo.';
        MissingDocumentNextLbl: Label 'Send the service order number in documentNo.', Comment = 'is-IS=Sendu númer þjónustupöntunarinnar í documentNo.';
        ManyLinesLbl: Label 'Service order %1 has %2 service item lines.', Comment = '%1 = order number, %2 = line count, is-IS=Þjónustupöntun %1 er með %2 þjónustuvörulínur.';
        ManyLinesNextLbl: Label 'Send serviceItemLineNo to choose the service item line.', Comment = 'is-IS=Sendu serviceItemLineNo til að velja þjónustuvörulínuna.';
        LineNotFoundLbl: Label 'Service item line %1 was not found.', Comment = '%1 = identifier, is-IS=Þjónustuvörulína %1 fannst ekki.';
        NoLinesLbl: Label 'Service order %1 was not found or has no service item lines.', Comment = '%1 = order number, is-IS=Þjónustupöntun %1 fannst ekki eða er ekki með neinar þjónustuvörulínur.';
        ConflictLbl: Label '%1 does not match the service item line (%2).', Comment = '%1 = parameter, %2 = value on the line, is-IS=%1 passar ekki við þjónustuvörulínuna (%2).';
        ConflictNextLbl: Label 'Send either the service item line or the codes, or codes that match the line.', Comment = 'is-IS=Sendu annaðhvort þjónustuvörulínuna eða kóðana, eða kóða sem passa við línuna.';
        MissingCodeLbl: Label '%1 is required by the fault reporting level %2.', Comment = '%1 = parameter, %2 = fault reporting level, is-IS=%1 er nauðsynlegt vegna villuskráningarstigsins %2.';
        MissingCodeNextLbl: Label 'Send %1 as well.', Comment = '%1 = parameter, is-IS=Sendu %1 líka.';
        LineCodeLbl: Label 'Service item line %1 %2 has no %3, which the fault reporting level %4 needs.', Comment = '%1 = document number, %2 = line number, %3 = field caption, %4 = fault reporting level, is-IS=Þjónustuvörulína %1 %2 er ekki með %3, sem villuskráningarstigið %4 þarf.';
        LineCodeNextLbl: Label 'Set %1 on the service item line with Data.Records.Set (table Service Item Line), then retry.', Comment = '%1 = field caption, is-IS=Settu %1 á þjónustuvörulínuna með Data.Records.Set (tafla Service Item Line) og reyndu svo aftur.';
        LevelOffLbl: Label 'Fault reporting is turned off in the service setup (Fault Reporting Level is None).', Comment = 'is-IS=Villuskráning er óvirk í þjónustugrunnstillingum (Fault Reporting Level er None).';
        LevelOffNextLbl: Label 'Ask an administrator to choose a Fault Reporting Level in Service Mgt. Setup.', Comment = 'is-IS=Biddu kerfisstjóra að velja Fault Reporting Level í Service Mgt. Setup.';
        UnknownLbl: Label '%1 is not a parameter here.', Comment = '%1 = parameter, is-IS=%1 er ekki færibreyta hér.';
        UnknownNextLbl: Label 'Remove %1. The parameters are documentNo, serviceItemLineNo, systemId, faultCode, symptomCode, faultAreaCode, serviceItemGroupCode and top.', Comment = '%1 = parameter, is-IS=Fjarlægðu %1. Færibreyturnar eru documentNo, serviceItemLineNo, systemId, faultCode, symptomCode, faultAreaCode, serviceItemGroupCode og top.';
        PermissionLbl: Label 'You do not have permission to read the table %1.', Comment = '%1 = table name, is-IS=Þú hefur ekki heimild til að lesa töfluna %1.';
        PermissionNextLbl: Label 'Ask an administrator for a Bifröst Service Management read permission set together with read access to service data.', Comment = 'is-IS=Biddu kerfisstjóra um lesheimildasett Bifröst þjónustustjórnunar ásamt lesaðgangi að þjónustugögnum.';

    /// <summary>Checks Foundation licensing and version, then returns the ranked suggestions. Nothing is written.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Suggest(Argument);
    end;

    local procedure Suggest(var Argument: Record "Message Argument ori")
    var
        ItemLine: Record "Service Item Line";
        Relationship: Record "Fault/Resol. Cod. Relationship";
        Setup: Record "Service Mgt. Setup";
        Request: JsonObject;
        DocumentNo: Text;
        IdText: Text;
        FaultCode: Text;
        SymptomCode: Text;
        FaultAreaCode: Text;
        GroupCode: Text;
        LineNo: Integer;
        Top: Integer;
        HasLineNo: Boolean;
        HasTop: Boolean;
        UseLine: Boolean;
        UseCodes: Boolean;
        Level: Integer;
    begin
        Request := Argument.GetRequestJson();
        if not OnlyDeclaredKeys(Request, Argument) then
            exit;
        if not ReadText(Request, 'documentNo', Argument, MaxStrLen(ItemLine."Document No."), DocumentNo) then
            exit;
        if not ReadText(Request, 'systemId', Argument, 50, IdText) then
            exit;
        if not ReadInteger(Request, 'serviceItemLineNo', Argument, 1, 2147483647, LineNo, HasLineNo) then
            exit;
        if not ReadText(Request, 'faultCode', Argument, MaxStrLen(ItemLine."Fault Code"), FaultCode) then
            exit;
        if not ReadText(Request, 'symptomCode', Argument, MaxStrLen(ItemLine."Symptom Code"), SymptomCode) then
            exit;
        if not ReadText(Request, 'faultAreaCode', Argument, MaxStrLen(ItemLine."Fault Area Code"), FaultAreaCode) then
            exit;
        if not ReadText(Request, 'serviceItemGroupCode', Argument, MaxStrLen(ItemLine."Service Item Group Code"), GroupCode) then
            exit;
        if not ReadInteger(Request, 'top', Argument, 1, 50, Top, HasTop) then
            exit;
        if not HasTop then
            Top := 10;

        UseLine := (DocumentNo <> '') or (IdText <> '') or HasLineNo;
        UseCodes := (FaultCode <> '') or (SymptomCode <> '') or (FaultAreaCode <> '') or (GroupCode <> '');
        if not UseLine and not UseCodes then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLbl, 'documentNo/systemId/faultCode', '', '', MissingNextLbl);
            exit;
        end;

        if not CanRead(Argument, ItemLine.ReadPermission(), ItemLine.TableName()) then
            exit;
        if not CanRead(Argument, Setup.ReadPermission(), Setup.TableName()) then
            exit;
        if not CanRead(Argument, Relationship.ReadPermission(), Relationship.TableName()) then
            exit;

        if UseLine then begin
            if not FindLine(Argument, DocumentNo, IdText, LineNo, HasLineNo, ItemLine) then
                exit;
            if not SameCode(Argument, 'faultCode', FaultCode, ItemLine."Fault Code") then
                exit;
            if not SameCode(Argument, 'symptomCode', SymptomCode, ItemLine."Symptom Code") then
                exit;
            if not SameCode(Argument, 'faultAreaCode', FaultAreaCode, ItemLine."Fault Area Code") then
                exit;
            if not SameCode(Argument, 'serviceItemGroupCode', GroupCode, ItemLine."Service Item Group Code") then
                exit;
            FaultCode := ItemLine."Fault Code";
            SymptomCode := ItemLine."Symptom Code";
            FaultAreaCode := ItemLine."Fault Area Code";
            GroupCode := ItemLine."Service Item Group Code";
        end;

        Setup.SetLoadFields("Fault Reporting Level");
        if Setup.Get() then
            Level := Setup."Fault Reporting Level";
        if Level = Setup."Fault Reporting Level"::None then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, LevelOffLbl, '', '', '', LevelOffNextLbl);
            exit;
        end;

        if not RequireCode(Argument, UseLine, ItemLine, 'faultCode', ItemLine.FieldCaption("Fault Code"), FaultCode, Level) then
            exit;
        if Level >= Setup."Fault Reporting Level"::"Fault+Symptom" then begin
            if not RequireCode(Argument, UseLine, ItemLine, 'symptomCode', ItemLine.FieldCaption("Symptom Code"), SymptomCode, Level) then
                exit;
        end else
            SymptomCode := '';
        if Level >= Setup."Fault Reporting Level"::"Fault+Symptom+Area (IRIS)" then begin
            if not RequireCode(Argument, UseLine, ItemLine, 'faultAreaCode', ItemLine.FieldCaption("Fault Area Code"), FaultAreaCode, Level) then
                exit;
        end else
            FaultAreaCode := '';

        Argument.SetResponseJson(BuildResponse(UseLine, ItemLine, Level, FaultCode, SymptomCode, FaultAreaCode, GroupCode, Top));
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildResponse(UseLine: Boolean; ItemLine: Record "Service Item Line"; Level: Integer; FaultCode: Text; SymptomCode: Text; FaultAreaCode: Text; GroupCode: Text; Top: Integer): JsonObject
    var
        Relationship: Record "Fault/Resol. Cod. Relationship";
        ResolutionCode: Record "Resolution Code";
        Setup: Record "Service Mgt. Setup";
        Response: JsonObject;
        Suggestion: JsonObject;
        Suggestions: JsonArray;
        Description: Text;
    begin
        Relationship.SetCurrentKey("Fault Code", Occurrences);
        Relationship.Ascending(false);
        Relationship.SetRange("Fault Code", FaultCode);
        if Level >= Setup."Fault Reporting Level"::"Fault+Symptom" then
            Relationship.SetRange("Symptom Code", SymptomCode);
        if Level >= Setup."Fault Reporting Level"::"Fault+Symptom+Area (IRIS)" then
            Relationship.SetRange("Fault Area Code", FaultAreaCode);
        // Rows calculated without service item groups have an empty group, so they apply to every group.
        if GroupCode <> '' then
            Relationship.SetFilter("Service Item Group Code", '%1|%2', GroupCode, '');
        if Relationship.FindSet() then
            repeat
                Clear(Suggestion);
                Description := Relationship.Description;
                if Description = '' then begin
                    ResolutionCode.SetLoadFields(Description);
                    if ResolutionCode.Get(Relationship."Resolution Code") then
                        Description := ResolutionCode.Description;
                end;
                Suggestion.Add('resolutionCode', Relationship."Resolution Code");
                Suggestion.Add('description', Description);
                Suggestion.Add('occurrences', Relationship.Occurrences);
                Suggestion.Add('createdManually', Relationship."Created Manually");
                Suggestion.Add('serviceItemGroupCode', Relationship."Service Item Group Code");
                Suggestion.Add('symptomCode', Relationship."Symptom Code");
                Suggestion.Add('faultAreaCode', Relationship."Fault Area Code");
                Suggestions.Add(Suggestion);
            until (Relationship.Next() = 0) or (Suggestions.Count() >= Top);

        Response.Add('status', 'Success');
        if UseLine then begin
            Response.Add('source', 'line');
            Response.Add('documentType', ItemLine."Document Type".Names().Get(ItemLine."Document Type".Ordinals().IndexOf(ItemLine."Document Type".AsInteger())));
            Response.Add('documentNo', ItemLine."Document No.");
            Response.Add('serviceItemLineNo', ItemLine."Line No.");
            Response.Add('serviceItemNo', ItemLine."Service Item No.");
        end else
            Response.Add('source', 'codes');
        Response.Add('faultReportingLevel', LevelName(Level));
        Response.Add('faultCode', FaultCode);
        Response.Add('symptomCode', SymptomCode);
        Response.Add('faultAreaCode', FaultAreaCode);
        Response.Add('serviceItemGroupCode', GroupCode);
        Response.Add('top', Top);
        Response.Add('count', Suggestions.Count());
        Response.Add('suggestions', Suggestions);
        exit(Response);
    end;

    local procedure FindLine(var Argument: Record "Message Argument ori"; DocumentNo: Text; IdText: Text; LineNo: Integer; HasLineNo: Boolean; var ItemLine: Record "Service Item Line"): Boolean
    var
        Id: Guid;
        LineCount: Integer;
    begin
        ItemLine.SetLoadFields("Document Type", "Document No.", "Line No.", "Service Item No.", "Service Item Group Code", "Fault Code", "Symptom Code", "Fault Area Code");
        if IdText <> '' then begin
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, GuidLbl, 'systemId', IdText, 'GUID', CorrectLbl);
                exit(false);
            end;
            if not ItemLine.GetBySystemId(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundLbl, IdText), 'systemId', IdText, '', MissingNextLbl);
                exit(false);
            end;
            if (DocumentNo <> '') and (UpperCase(DocumentNo) <> ItemLine."Document No.") then
                exit(Conflict(Argument, 'documentNo', ItemLine."Document No."));
            if HasLineNo and (LineNo <> ItemLine."Line No.") then
                exit(Conflict(Argument, 'serviceItemLineNo', Format(ItemLine."Line No.", 0, 9)));
            exit(true);
        end;
        if DocumentNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingDocumentLbl, 'documentNo', '', '', MissingDocumentNextLbl);
            exit(false);
        end;
        if HasLineNo then begin
            if not ItemLine.Get(ItemLine."Document Type"::Order, CopyStr(UpperCase(DocumentNo), 1, MaxStrLen(ItemLine."Document No.")), LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundLbl, DocumentNo + ' ' + Format(LineNo, 0, 9)), 'serviceItemLineNo', Format(LineNo, 0, 9), '', MissingNextLbl);
                exit(false);
            end;
            exit(true);
        end;
        ItemLine.SetRange("Document Type", ItemLine."Document Type"::Order);
        ItemLine.SetRange("Document No.", UpperCase(DocumentNo));
        LineCount := ItemLine.Count();
        if LineCount = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NoLinesLbl, DocumentNo), 'documentNo', DocumentNo, '', MissingNextLbl);
            exit(false);
        end;
        if LineCount > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(ManyLinesLbl, DocumentNo, LineCount), 'serviceItemLineNo', '', '', ManyLinesNextLbl);
            exit(false);
        end;
        ItemLine.FindFirst();
        ItemLine.Reset();
        exit(true);
    end;

    local procedure SameCode(var Argument: Record "Message Argument ori"; KeyName: Text; Supplied: Text; OnLine: Code[10]): Boolean
    begin
        if (Supplied = '') or (UpperCase(Supplied) = OnLine) then
            exit(true);
        exit(Conflict(Argument, KeyName, OnLine));
    end;

    local procedure Conflict(var Argument: Record "Message Argument ori"; KeyName: Text; OnLine: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(ConflictLbl, KeyName, OnLine), KeyName, '', OnLine, ConflictNextLbl);
        exit(false);
    end;

    local procedure RequireCode(var Argument: Record "Message Argument ori"; UseLine: Boolean; ItemLine: Record "Service Item Line"; KeyName: Text; Caption: Text; Value: Text; Level: Integer): Boolean
    begin
        if Value <> '' then
            exit(true);
        if UseLine then
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed,
                StrSubstNo(LineCodeLbl, ItemLine."Document No.", ItemLine."Line No.", Caption, LevelName(Level)),
                KeyName, '', '', StrSubstNo(LineCodeNextLbl, Caption))
        else
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter,
                StrSubstNo(MissingCodeLbl, KeyName, LevelName(Level)), KeyName, '', '', StrSubstNo(MissingCodeNextLbl, KeyName));
        exit(false);
    end;

    local procedure ReadText(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; Maximum: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not Request.Get(KeyName, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidTextLbl, KeyName, Maximum), KeyName, Raw, 'string', CorrectLbl);
            exit(false);
        end;
        Value := Token.AsValue().AsText().Trim();
        if (Value = '') or (StrLen(Value) > Maximum) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidTextLbl, KeyName, Maximum), KeyName, Value, '', CorrectLbl);
            exit(false);
        end;
        Value := UpperCase(Value);
        exit(true);
    end;

    local procedure ReadInteger(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; Minimum: Integer; Maximum: Integer; var Value: Integer; var Present: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Parsed: BigInteger;
    begin
        Value := 0;
        Present := Request.Get(KeyName, Token);
        if not Present then
            exit(true);
        Token.WriteTo(Raw);
        if Token.IsValue() and (CopyStr(Raw, 1, 1) <> '"') and Evaluate(Parsed, Raw, 9) then
            if (Parsed >= Minimum) and (Parsed <= Maximum) then begin
                Value := Parsed;
                exit(true);
            end;
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat,
            StrSubstNo(InvalidIntegerLbl, KeyName, Minimum, Maximum), KeyName, Raw, StrSubstNo('%1..%2', Minimum, Maximum), CorrectLbl);
        exit(false);
    end;

    local procedure CanRead(var Argument: Record "Message Argument ori"; Allowed: Boolean; TableName: Text): Boolean
    begin
        if Allowed then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(PermissionLbl, TableName), '', TableName, '', PermissionNextLbl);
        exit(false);
    end;

    local procedure OnlyDeclaredKeys(Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        Declared: List of [Text];
        KeyName: Text;
    begin
        Declared := 'documentNo|serviceItemLineNo|systemId|faultCode|symptomCode|faultAreaCode|serviceItemGroupCode|top'.Split('|');
        foreach KeyName in Request.Keys() do
            if not Declared.Contains(KeyName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownLbl, KeyName), KeyName, '', '', StrSubstNo(UnknownNextLbl, KeyName));
                exit(false);
            end;
        exit(true);
    end;

    local procedure LevelName(Level: Integer): Text
    var
        Setup: Record "Service Mgt. Setup";
    begin
        case Level of
            Setup."Fault Reporting Level"::Fault:
                exit('Fault');
            Setup."Fault Reporting Level"::"Fault+Symptom":
                exit('FaultSymptom');
            Setup."Fault Reporting Level"::"Fault+Symptom+Area (IRIS)":
                exit('FaultSymptomArea');
        end;
        exit('None');
    end;

    /// <summary>Enables discovery without reading application tables.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the service item line filter scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Item Line");
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Suggests the resolution codes that fixed the same fault before, most frequent first, for a service item line or for fault codes sent directly. Reads only.', Comment = 'is-IS=Stingur upp á lausnarkóðum sem lagfærðu sömu villu áður, algengasta fyrst, fyrir þjónustuvörulínu eða villukóða sem sendir eru beint. Les eingöngu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'fault code, resolution code, suggest fix, repair history', Comment = 'is-IS=villukóði, lausnarkóði, tillaga að lagfæringu, viðgerðarsaga';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.documentNo + data.serviceItemLineNo', 'service order line', 'Service item line on a service order. serviceItemLineNo can be left out when the order has one service item line.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'SystemId of a service item line.'));
        Target.Add(Contract.TargetEntry('data.faultCode', 'codes', 'Fault, symptom, fault area and service item group codes sent directly instead of a line.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Service order number, at most 20 characters. Use with serviceItemLineNo.'));
        Parameters.Add(Contract.Parameter('serviceItemLineNo', 'integer', false, 'Line No. of the service item line. Required when the order has more than one service item line.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'SystemId (GUID) of a service item line, instead of documentNo and serviceItemLineNo.'));
        Parameters.Add(Contract.Parameter('faultCode', 'string', false, 'Fault code, at most 10 characters. Required when no service item line is sent.'));
        Parameters.Add(Contract.Parameter('symptomCode', 'string', false, 'Symptom code. Required without a line when the fault reporting level includes the symptom.'));
        Parameters.Add(Contract.Parameter('faultAreaCode', 'string', false, 'Fault area code. Required without a line when the fault reporting level includes the fault area.'));
        Parameters.Add(Contract.Parameter('serviceItemGroupCode', 'string', false, 'Service item group code. Limits the result to that group and to rows without a group.'));
        Parameters.Add(Contract.Parameter('top', 'integer', false, 'Number of suggestions to return, 1 to 50. Default 10.'));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('source', 'string', 'line when a service item line was sent, codes when the codes were sent directly.'));
        Fields.Add(Contract.ResponseField('documentType', 'string', 'Document type of the service item line (line source only).'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'Service order number (line source only).'));
        Fields.Add(Contract.ResponseField('serviceItemLineNo', 'integer', 'Line No. of the service item line (line source only).'));
        Fields.Add(Contract.ResponseField('serviceItemNo', 'string', 'Service item on the line (line source only).'));
        Fields.Add(Contract.ResponseField('faultReportingLevel', 'string', 'Fault reporting level from the service setup: Fault, FaultSymptom or FaultSymptomArea.'));
        Fields.Add(Contract.ResponseField('faultCode', 'string', 'Fault code used as the filter.'));
        Fields.Add(Contract.ResponseField('symptomCode', 'string', 'Symptom code used as the filter; empty when the level does not include the symptom.'));
        Fields.Add(Contract.ResponseField('faultAreaCode', 'string', 'Fault area code used as the filter; empty when the level does not include the fault area.'));
        Fields.Add(Contract.ResponseField('serviceItemGroupCode', 'string', 'Service item group used as the filter; empty means every group.'));
        Fields.Add(Contract.ResponseField('top', 'integer', 'Maximum number of suggestions returned.'));
        Fields.Add(Contract.ResponseField('count', 'integer', 'Number of suggestions returned. 0 when there is no history.'));
        Fields.Add(Contract.ResponseField('suggestions', 'array', 'Ranked by occurrences, highest first. Each entry has resolutionCode, description, occurrences, createdManually, serviceItemGroupCode, symptomCode and faultAreaCode.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Neither a service item line nor a fault code was sent, the order has several service item lines and serviceItemLineNo is missing, or a code the fault reporting level needs is missing.', 'Send documentNo and serviceItemLineNo, systemId, or faultCode with the codes the level needs.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A code or number is empty or too long.', 'Send a value within the documented length.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value has the wrong JSON type, systemId is not a GUID, or top or serviceItemLineNo is outside its range.', 'Correct the value and retry.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has a parameter that is not documented here.', 'Remove the undocumented parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The service item line or service order was not found.', 'Read Service Item Line with Data.Records.Get and send an existing line.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'The line identifiers or the sent codes do not match the service item line.', 'Send either the line or the codes, or codes that match the line.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Fault reporting is turned off in the service setup, or the service item line lacks a code that the fault reporting level needs.', 'Set the missing code on the service item line with Data.Records.Set, or ask an administrator to choose a fault reporting level.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read service item lines, the service setup or the fault/resolution code relationships.', 'Ask an administrator for the Bifröst Service Management read permissions and read access to service data.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. Reads the fault/resolution code relationships, the service item line and the service setup.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST SvcRead ori');
        Effect.Add('permissions', 'The caller needs read access to service item lines, the service setup and the fault/resolution code relationships. A Bifröst read role without SUPER works when it also has read access to that data, for example D365 READ.');
        Effect.Add('preconditions', 'A fault reporting level other than None in the service setup. The suggestions reflect the last run of the Insert Fault/Resol. Relations batch job in Business Central.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Set the fault, symptom, fault area and resolution codes on a service item line.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read Service Item Line and the fault/resolution code relationships.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Post', 'Post the service order; posted shipments feed the next relationship recalculation.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Data.Records.Set', 'Record the fault (and symptom and fault area, as the level needs) on the service item line.'));
        Steps.Add(Contract.WorkflowStep('Service.FaultResolution.Suggest', 'Get the resolution codes that fixed the same fault before.'));
        Steps.Add(Contract.WorkflowStep('Data.Records.Set', 'Record the chosen resolution code on the service item line.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('description', 'Record the fault, ask for suggestions, then record the resolution that was used. The relationship table is rebuilt in Business Central by the Insert Fault/Resol. Relations batch job or a job queue entry.');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        LineExample: JsonObject;
        CodeExample: JsonObject;
        LineData: JsonObject;
        CodeData: JsonObject;
    begin
        LineData.Add('documentNo', 'SO000001');
        LineData.Add('serviceItemLineNo', 10000);
        LineExample.Add('description', 'Suggest resolutions for the fault recorded on a service item line.');
        LineExample.Add('data', LineData);
        Examples.Add(LineExample);
        CodeData.Add('faultCode', 'NOPOWER');
        CodeData.Add('symptomCode', 'DEAD');
        CodeData.Add('top', 5);
        CodeExample.Add('description', 'Suggest the five most frequent resolutions for a fault and symptom sent directly.');
        CodeExample.Add('data', CodeData);
        Examples.Add(CodeExample);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains how the fault reporting level and the service item group filter the result.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The fault reporting level in the service setup decides which codes must match: Fault uses the fault code, FaultSymptom adds the symptom code, FaultSymptomArea adds the fault area code. With a service item group, rows for that group and rows without a group are returned. No history returns an empty list with status Success.';
        exit(true);
    end;

    /// <summary>Summarizes the result.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the filters applied and a ranked list of resolution codes with description, occurrences and whether the row was created manually.';
        exit(true);
    end;
}
