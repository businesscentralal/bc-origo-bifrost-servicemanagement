namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>
/// Implements Service.Order.AdjustPrice: applies the fixed, maximum or minimum price of a service price adjustment group
/// to the service lines of one service item line on a service order or quote, previews it, or resets it.
/// </summary>
codeunit 10076140 "Svc Price Adjust Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        InvalidBooleanLbl: Label '%1 must be true or false.', Comment = '%1 = parameter, is-IS=%1 verður að vera true eða false.';
        DocumentTypeLbl: Label 'documentType must be Order or Quote.', Comment = 'is-IS=documentType verður að vera Order eða Quote.';
        GuidLbl: Label 'systemId must be a nonempty GUID.', Comment = 'is-IS=systemId verður að vera gilt GUID sem er ekki tómt.';
        CorrectLbl: Label 'Send the value in the documented format and retry.', Comment = 'is-IS=Sendu gildið á sniðinu sem lýst er og reyndu aftur.';
        MissingLbl: Label 'Send the service item line: documentNo and serviceItemLineNo, or systemId.', Comment = 'is-IS=Sendu þjónustuvörulínuna: documentNo og serviceItemLineNo, eða systemId.';
        MissingNextLbl: Label 'Read the service item lines with Data.Records.Get (table Service Item Line) and send documentNo and serviceItemLineNo.', Comment = 'is-IS=Lestu þjónustuvörulínurnar með Data.Records.Get (tafla Service Item Line) og sendu documentNo og serviceItemLineNo.';
        ManyLinesLbl: Label 'Service document %1 has %2 service item lines.', Comment = '%1 = document number, %2 = line count, is-IS=Þjónustuskjal %1 er með %2 þjónustuvörulínur.';
        ManyLinesNextLbl: Label 'Send serviceItemLineNo to choose the service item line.', Comment = 'is-IS=Sendu serviceItemLineNo til að velja þjónustuvörulínuna.';
        LineNotFoundLbl: Label 'Service item line %1 was not found.', Comment = '%1 = identifier, is-IS=Þjónustuvörulína %1 fannst ekki.';
        NoLinesLbl: Label 'Service document %1 was not found or has no service item lines.', Comment = '%1 = document number, is-IS=Þjónustuskjal %1 fannst ekki eða er ekki með neinar þjónustuvörulínur.';
        ConflictLbl: Label '%1 does not match the service item line (%2).', Comment = '%1 = parameter, %2 = value on the line, is-IS=%1 passar ekki við þjónustuvörulínuna (%2).';
        ConflictNextLbl: Label 'Send either systemId or documentNo and serviceItemLineNo, or values that match the line.', Comment = 'is-IS=Sendu annaðhvort systemId eða documentNo og serviceItemLineNo, eða gildi sem passa við línuna.';
        WrongDocumentLbl: Label 'Service item line %1 is not on a service order or service quote.', Comment = '%1 = identifier, is-IS=Þjónustuvörulína %1 er ekki á þjónustupöntun eða þjónustutilboði.';
        WrongDocumentNextLbl: Label 'Adjust prices on a service order or service quote.', Comment = 'is-IS=Leiðréttu verð á þjónustupöntun eða þjónustutilboði.';
        PreviewResetLbl: Label 'preview and reset cannot both be true.', Comment = 'is-IS=preview og reset geta ekki bæði verið true.';
        PreviewResetNextLbl: Label 'Send preview to see the new prices, or reset to restore the prices of adjusted lines.', Comment = 'is-IS=Sendu preview til að sjá nýju verðin, eða reset til að endurheimta verð leiðréttra lína.';
        UnknownLbl: Label '%1 is not a parameter here.', Comment = '%1 = parameter, is-IS=%1 er ekki færibreyta hér.';
        UnknownNextLbl: Label 'Remove %1. The parameters are documentNo, documentType, serviceItemLineNo, systemId, preview and reset.', Comment = '%1 = parameter, is-IS=Fjarlægðu %1. Færibreyturnar eru documentNo, documentType, serviceItemLineNo, systemId, preview og reset.';
        FailedNextLbl: Label 'Correct the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur. Engu var breytt.';

    /// <summary>Checks Foundation licensing, version and the write gate, then validates the request and runs the adjustment.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        WriteCheck: Codeunit "Svc Write Check ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite(Format(Argument.Type));
        Adjust(Argument);
    end;

    local procedure Adjust(var Argument: Record "Message Argument ori")
    var
        ItemLine: Record "Service Item Line";
        Processor: Codeunit "Svc Price Adjust Proc ori";
        Request: JsonObject;
        Response: JsonObject;
        ErrorCode: JsonToken;
        DocumentNo: Text;
        DocumentTypeText: Text;
        IdText: Text;
        DocumentType: Enum "Service Document Type";
        LineNo: Integer;
        HasLineNo: Boolean;
        Preview: Boolean;
        Reset: Boolean;
    begin
        Request := Argument.GetRequestJson();
        if not OnlyDeclaredKeys(Request, Argument) then
            exit;
        if not ReadText(Request, 'documentNo', Argument, MaxStrLen(ItemLine."Document No."), DocumentNo) then
            exit;
        if not ReadText(Request, 'documentType', Argument, 10, DocumentTypeText) then
            exit;
        if not ReadText(Request, 'systemId', Argument, 38, IdText) then
            exit;
        if not ReadInteger(Request, 'serviceItemLineNo', Argument, 1, 2147483647, LineNo, HasLineNo) then
            exit;
        if not ReadBoolean(Request, 'preview', Argument, Preview) then
            exit;
        if not ReadBoolean(Request, 'reset', Argument, Reset) then
            exit;
        case DocumentTypeText of
            '', 'ORDER':
                DocumentType := DocumentType::Order;
            'QUOTE':
                DocumentType := DocumentType::Quote;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentTypeLbl, 'documentType', DocumentTypeText, 'Order|Quote', CorrectLbl);
                exit;
            end;
        end;
        if Preview and Reset then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, PreviewResetLbl, 'reset', 'true', '', PreviewResetNextLbl);
            exit;
        end;
        if (DocumentNo = '') and (IdText = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLbl, 'documentNo/systemId', '', '', MissingNextLbl);
            exit;
        end;
        if not FindLine(Argument, DocumentType, DocumentTypeText <> '', DocumentNo, IdText, LineNo, HasLineNo, ItemLine) then
            exit;

        Processor.SetRequest(ItemLine, Preview, Reset);
        if Argument."Omit Commit" then
            Processor.Run(Argument)
        else
            if not Processor.Run(Argument) then begin
                Argument.RespondWithLastError();
                Response := Argument.GetResponseJson();
                if Response.Get('code', ErrorCode) then
                    if ErrorCode.AsValue().AsText() = 'Retryable' then
                        exit;
                if Response.Contains('nextStep') then
                    Response.Replace('nextStep', FailedNextLbl)
                else
                    Response.Add('nextStep', FailedNextLbl);
                Argument.SetResponseJson(Response);
            end;
    end;

    local procedure FindLine(var Argument: Record "Message Argument ori"; DocumentType: Enum "Service Document Type"; HasType: Boolean; DocumentNo: Text; IdText: Text; LineNo: Integer; HasLineNo: Boolean; var ItemLine: Record "Service Item Line"): Boolean
    var
        Id: Guid;
        LineCount: Integer;
    begin
        if IdText <> '' then begin
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, GuidLbl, 'systemId', IdText, 'GUID', CorrectLbl);
                exit(false);
            end;
            if not ItemLine.GetBySystemId(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundLbl, IdText), 'systemId', IdText, '', MissingNextLbl);
                exit(false);
            end;
            if (DocumentNo <> '') and (DocumentNo <> ItemLine."Document No.") then
                exit(Conflict(Argument, 'documentNo', ItemLine."Document No."));
            if HasLineNo and (LineNo <> ItemLine."Line No.") then
                exit(Conflict(Argument, 'serviceItemLineNo', Format(ItemLine."Line No.", 0, 9)));
            if HasType and (DocumentType <> ItemLine."Document Type") then
                exit(Conflict(Argument, 'documentType', Format(ItemLine."Document Type")));
            if not (ItemLine."Document Type" in [ItemLine."Document Type"::Order, ItemLine."Document Type"::Quote]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(WrongDocumentLbl, IdText), 'systemId', IdText, '', WrongDocumentNextLbl);
                exit(false);
            end;
            exit(true);
        end;
        if HasLineNo then begin
            if not ItemLine.Get(DocumentType, CopyStr(DocumentNo, 1, MaxStrLen(ItemLine."Document No.")), LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundLbl, DocumentNo + ' ' + Format(LineNo, 0, 9)), 'serviceItemLineNo', Format(LineNo, 0, 9), '', MissingNextLbl);
                exit(false);
            end;
            exit(true);
        end;
        ItemLine.SetRange("Document Type", DocumentType);
        ItemLine.SetRange("Document No.", DocumentNo);
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

    local procedure Conflict(var Argument: Record "Message Argument ori"; KeyName: Text; OnLine: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(ConflictLbl, KeyName, OnLine), KeyName, '', OnLine, ConflictNextLbl);
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

    local procedure ReadBoolean(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := false;
        if not Request.Get(KeyName, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if Raw in ['true', 'false'] then begin
            Value := Raw = 'true';
            exit(true);
        end;
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidBooleanLbl, KeyName), KeyName, Raw, 'boolean', CorrectLbl);
        exit(false);
    end;

    local procedure OnlyDeclaredKeys(Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        KeyName: Text;
    begin
        foreach KeyName in Request.Keys() do
            if not (KeyName in ['documentNo', 'documentType', 'serviceItemLineNo', 'systemId', 'preview', 'reset']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownLbl, KeyName), KeyName, '', '', StrSubstNo(UnknownNextLbl, KeyName));
                exit(false);
            end;
        exit(true);
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
        DescriptionLbl: Label 'Applies the fixed, maximum or minimum price of a service price adjustment group to the lines of a service item line, or previews or resets it.', Comment = 'is-IS=Beitir föstu, hámarks- eða lágmarksverði verðleiðréttingarflokks þjónustu á línur þjónustuvörulínu, eða forskoðar eða endurstillir það.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized catalogue search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'service price adjustment, fixed price repair, price cap, reset adjusted prices', Comment = 'is-IS=verðleiðrétting þjónustu, viðgerð á föstu verði, verðþak, endurstilla leiðrétt verð';
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
        Target.Add(Contract.TargetEntry('data.documentNo + data.serviceItemLineNo', 'service item line', 'Service item line on a service order (default) or, with documentType Quote, a service quote. serviceItemLineNo can be left out when the document has one service item line.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'SystemId of a service item line.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('documentNo', 'string', false, 'Service order or quote number, at most 20 characters. Use with serviceItemLineNo.'));
        Parameters.Add(Contract.Parameter('documentType', 'string', false, 'Order (default) or Quote.'));
        Parameters.Add(Contract.Parameter('serviceItemLineNo', 'integer', false, 'Line No. of the service item line. Required when the document has more than one service item line.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'SystemId (GUID) of a service item line, instead of documentNo and serviceItemLineNo.'));
        Parameters.Add(Contract.Parameter('preview', 'boolean', false, 'true returns the new prices without writing them. Default false.'));
        Parameters.Add(Contract.Parameter('reset', 'boolean', false, 'true restores the normal prices of the lines that were adjusted. Default false. Cannot be combined with preview.'));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('mode', 'string', 'adjust or reset.'));
        Fields.Add(Contract.ResponseField('preview', 'boolean', 'true when nothing was written.'));
        Fields.Add(Contract.ResponseField('changed', 'boolean', 'true when service line prices were written. false for a preview, and for a Maximum or Minimum adjustment that is already within its limit.'));
        Fields.Add(Contract.ResponseField('documentType', 'string', 'Order or Quote.'));
        Fields.Add(Contract.ResponseField('documentNo', 'string', 'Service document number.'));
        Fields.Add(Contract.ResponseField('serviceItemLineNo', 'integer', 'Line No. of the service item line.'));
        Fields.Add(Contract.ResponseField('servicePriceGroupCode', 'string', 'Service price group on the service item line.'));
        Fields.Add(Contract.ResponseField('adjustmentGroupCode', 'string', 'Price adjustment group that decides which lines are adjusted (adjust only).'));
        Fields.Add(Contract.ResponseField('adjustmentType', 'string', 'Fixed, Maximum or Minimum (adjust only).'));
        Fields.Add(Contract.ResponseField('targetAmount', 'number', 'Amount of the price group setup (adjust only).'));
        Fields.Add(Contract.ResponseField('includeVAT', 'boolean', 'true when the target amount includes VAT (adjust only).'));
        Fields.Add(Contract.ResponseField('includeDiscounts', 'boolean', 'false means line discounts are removed before the adjustment (adjust only).'));
        Fields.Add(Contract.ResponseField('discountsRemoved', 'boolean', 'true when line discounts were removed (adjust only).'));
        Fields.Add(Contract.ResponseField('totalBefore', 'number', 'Total of the covered lines as stored on the document, in the setup tax basis: including VAT when includeVAT is true, otherwise excluding VAT (adjust only).'));
        Fields.Add(Contract.ResponseField('comparedTotal', 'number', 'Total that is compared with the target amount, in the same tax basis; without line discounts when includeDiscounts is false (adjust only).'));
        Fields.Add(Contract.ResponseField('totalAfter', 'number', 'Total of the covered lines after the adjustment, in the same tax basis; equals totalBefore when nothing is adjusted (adjust only).'));
        Fields.Add(Contract.ResponseField('lines', 'array', 'Each entry has lineNo, type, no, oldUnitPrice, newUnitPrice, oldAmount, newAmount and status (None, Adjusted or Modified); adjust adds description, quantity and weight.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No service item line was sent, or the document has several service item lines and serviceItemLineNo is missing.', 'Send documentNo and serviceItemLineNo, or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value is empty or too long, documentType is not Order or Quote, or preview and reset are both true.', 'Send a documented value.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value has the wrong JSON type, systemId is not a GUID, or preview or reset is not true or false.', 'Correct the value and retry.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has a parameter that is not documented here.', 'Remove the undocumented parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The service item line or service document was not found.', 'Read Service Item Line with Data.Records.Get and send an existing line.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'systemId and documentNo, serviceItemLineNo or documentType point to different lines.', 'Send either systemId or documentNo and serviceItemLineNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The service item line has no service price group or no matching price group setup, no service lines fall under the adjustment group, a line is already invoiced, or there is nothing to reset.', 'Set the service price group with Data.Records.Set, adjust before invoicing, or adjust before you reset.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no Bifröst Service Management write permission or cannot change service lines.', 'Ask an administrator for the Bifröst Service Management permission set and write access to service documents.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused a new price on a service line.', 'Correct the Business Central error and retry. Nothing was changed.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Changes Unit Price, Line Amount, Line Discount and Price Adjmt. Status on the service lines of one service item line. reset restores the normal prices of the adjusted lines. preview writes nothing. Nothing is deleted.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Svc ori');
        Effect.Add('permissions', 'The caller needs the Bifröst Service Management permission set and write access to service lines. The read role is refused, preview included.');
        Effect.Add('preconditions', 'A service order or quote whose service item line has a service price group with a price group setup and an adjustment group; the lines are not invoiced.');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Set the service price group on the service item line before the adjustment.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read Service Item Line and Service Line to choose the line and check the prices.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Post', 'Post the service order with the adjusted prices.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Data.Records.Set', 'Set the service price group on the service item line.'));
        Steps.Add(Contract.WorkflowStep('Service.Order.AdjustPrice', 'Send preview true to see the new prices.'));
        Steps.Add(Contract.WorkflowStep('Service.Order.AdjustPrice', 'Send the same line without preview to write the prices, or with reset true to undo them.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('description', 'Choose the price group, preview the spread, then apply it. Reset restores the normal prices of the adjusted lines.');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        AdjustExample: JsonObject;
        ResetExample: JsonObject;
        AdjustData: JsonObject;
        ResetData: JsonObject;
    begin
        AdjustData.Add('documentNo', 'SO000001');
        AdjustData.Add('serviceItemLineNo', 10000);
        AdjustData.Add('preview', true);
        AdjustExample.Add('description', 'Preview the fixed price of the service price group on a service item line.');
        AdjustExample.Add('data', AdjustData);
        Examples.Add(AdjustExample);
        ResetData.Add('documentNo', 'SO000001');
        ResetData.Add('serviceItemLineNo', 10000);
        ResetData.Add('reset', true);
        ResetExample.Add('description', 'Restore the normal prices of the adjusted lines.');
        ResetExample.Add('data', ResetData);
        Examples.Add(ResetExample);
        exit(true);
    end;

    /// <summary>Uses Foundation's default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains how the amount is spread.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The target amount is spread over the lines by their share of the total; the last line takes the rounding difference so the lines add up to the target. Fixed always applies; Maximum only lowers a total above the amount; Minimum only raises a total below it. The comparison uses the setup tax basis, so a target without VAT is compared with net amounts also on a document with prices including VAT. When nothing is adjusted, every line reports its stored prices. Warranty lines, lines outside the adjustment group and lines with nothing left to consume are left out. Posted documents are never changed. Omit Commit keeps the caller transaction.';
        exit(true);
    end;

    /// <summary>Summarizes the result.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns the price group setup used, the totals before and after, and the old and new unit price and amount of every line.';
        exit(true);
    end;
}
