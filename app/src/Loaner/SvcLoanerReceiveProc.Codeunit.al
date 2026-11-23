namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Document;
using Microsoft.Service.History;
using Microsoft.Service.Loaner;
using Origo.Bifrost;

/// <summary>Validates all loaner identifiers and receives the matching loan inside a rollback boundary.</summary>
codeunit 10076106 "Svc Loaner Receive Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Loaner: Record Loaner;
        Entry: Record "Loaner Entry";
        OrderLine: Record "Service Item Line";
        ShipmentLine: Record "Service Shipment Item Line";
        Management: Codeunit ServLoanerManagement;
        Response: JsonObject;
        Mode: Integer;
    begin
        // Lock the open entry before checking its identity and state again at the write boundary.
        Entry.LockTable();
        if not Resolve(Rec, Entry, OrderLine, ShipmentLine, Loaner, Mode) then
            exit;
        case Mode of
            1: Management.ReceiveLoaner(OrderLine);
            2: Management.ReceiveLoanerShipment(ShipmentLine);
            3: begin
                Loaner.CalcFields(Lent, "Document Type", "Document No.");
                Management.Receive(Loaner);
            end;
        end;
        Entry.Get(Entry."Entry No.");
        Entry.TestField(Lent, false);
        Response.Add('status', 'Success');
        Response.Add('loanerNo', Entry."Loaner No.");
        Response.Add('loanerEntryNo', Entry."Entry No.");
        Response.Add('documentType', Entry."Document Type".Names().Get(Entry."Document Type".Ordinals().IndexOf(Entry."Document Type".AsInteger())));
        Response.Add('documentNo', Entry."Document No.");
        Response.Add('serviceItemLineNo', Entry."Service Item Line No.");
        Response.Add('dateReceived', Entry."Date Received");
        Response.Add('timeReceived', Entry."Time Received");
        Response.Add('lent', Entry.Lent);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    var
        Parser: Codeunit "Svc Doc Request ori";
        MissingLbl: Label 'Send documentNo with serviceItemLineNo, postedShipmentNo with lineNo, or loanerNo.', Comment = 'is-IS=Sendu documentNo með serviceItemLineNo, postedShipmentNo með lineNo eða loanerNo.';
        FindLbl: Label 'The loaner or document line was not found. Read the available loaners and document lines with Data.Records.Get and retry.', Comment = 'is-IS=Lánstækið eða skjallínan fannst ekki. Lestu tiltæk lánstæki og skjallínur með Data.Records.Get og reyndu aftur.';
        NotLentLbl: Label 'No open loan matches this identifier. Check that the loaner is lent on this document before receiving it.', Comment = 'is-IS=Ekkert opið lán passar við auðkennið. Gakktu úr skugga um að lánstækið sé í útláni á þessu skjali áður en þú tekur við því.';
        ConflictLbl: Label 'The identifiers name different loans. Send identifiers for the same loaner and document line.', Comment = 'is-IS=Auðkennin vísa á mismunandi lán. Sendu auðkenni fyrir sama lánstæki og sömu skjallínu.';
        NativeLbl: Label 'Correct the Business Central error and retry receiving the loaner. Nothing was changed.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur að taka við lánstækinu. Engu var breytt.';

    /// <summary>Checks licensing and the full-role write gate, preserving the caller transaction when requested.</summary>
    internal procedure Dispatch(var Argument: Record "Message Argument ori")
    var
        WriteCheck: Codeunit "Svc Write Check ori";
        Processor: Codeunit "Svc Loaner Receive Proc ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Loaner.Receive');
        Argument.SetErrorContext('', '', NativeLbl);
        ClearLastError();
        if Argument."Omit Commit" then
            Processor.Run(Argument)
        else
            if not Codeunit.Run(Codeunit::"Svc Loaner Receive Proc ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
    end;

    local procedure Resolve(var Argument: Record "Message Argument ori"; var Entry: Record "Loaner Entry"; var OrderLine: Record "Service Item Line"; var ShipmentLine: Record "Service Shipment Item Line"; var Loaner: Record Loaner; var Mode: Integer): Boolean
    var
        Shipment: Record "Service Shipment Header";
        Candidate: Record "Loaner Entry";
        Request: JsonObject;
        DocumentNo: Text;
        ShipmentNo: Text;
        LoanerNo: Text;
        ItemLineNo: Integer;
        ShipmentLineNo: Integer;
    begin
        if not Parser.CheckKeys(Argument, 'documentNo,serviceItemLineNo,postedShipmentNo,lineNo,loanerNo') then
            exit(false);
        Request := Argument.GetRequestJson();
        if not Parser.ReadText(Argument, Request, 'documentNo', 20, DocumentNo) then
            exit(false);
        if not Parser.ReadText(Argument, Request, 'postedShipmentNo', 20, ShipmentNo) then
            exit(false);
        if not Parser.ReadText(Argument, Request, 'loanerNo', 20, LoanerNo) then
            exit(false);
        if not Parser.ReadPositiveInteger(Argument, Request, 'serviceItemLineNo', ItemLineNo) then
            exit(false);
        if not Parser.ReadPositiveInteger(Argument, Request, 'lineNo', ShipmentLineNo) then
            exit(false);
        if ((DocumentNo <> '') xor (ItemLineNo <> 0)) or ((ShipmentNo <> '') xor (ShipmentLineNo <> 0)) or
           ((DocumentNo = '') and (ShipmentNo = '') and (LoanerNo = '')) then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, '', MissingLbl));
        if DocumentNo <> '' then begin
            OrderLine.ReadIsolation := IsolationLevel::UpdLock;
            if not OrderLine.Get(OrderLine."Document Type"::Order, DocumentNo, ItemLineNo) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'documentNo', FindLbl));
            if not FindEntry(Argument, OrderLine."Loaner No.", DocumentNo, ItemLineNo, true, Candidate) then
                exit(false);
            Entry := Candidate;
            Mode := 1;
        end;
        if ShipmentNo <> '' then begin
            ShipmentLine.ReadIsolation := IsolationLevel::UpdLock;
            if not ShipmentLine.Get(ShipmentNo, ShipmentLineNo) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'postedShipmentNo', FindLbl));
            Shipment.SetLoadFields("Order No.");
            if not Shipment.Get(ShipmentNo) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'postedShipmentNo', FindLbl));
            if not FindEntry(Argument, ShipmentLine."Loaner No.", Shipment."Order No.", ShipmentLineNo, true, Candidate) then
                exit(false);
            if not MergeEntry(Argument, Entry, Candidate, Mode) then
                exit(false);
            Mode := 2;
        end;
        if LoanerNo <> '' then begin
            if not Loaner.Get(LoanerNo) then
                exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'loanerNo', FindLbl));
            if not FindEntry(Argument, LoanerNo, '', 0, false, Candidate) then
                exit(false);
            if not MergeEntry(Argument, Entry, Candidate, Mode) then
                exit(false);
            if Mode = 0 then
                Mode := 3;
        end;
        exit(true);
    end;

    local procedure FindEntry(var Argument: Record "Message Argument ori"; LoanerNo: Text; DocumentNo: Text; LineNo: Integer; OrderOnly: Boolean; var Entry: Record "Loaner Entry"): Boolean
    begin
        if LoanerNo = '' then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', NotLentLbl));
        Entry.Reset();
        Entry.ReadIsolation := IsolationLevel::UpdLock;
        Entry.SetRange("Loaner No.", LoanerNo);
        Entry.SetRange(Lent, true);
        if OrderOnly then begin
            Entry.SetRange("Document Type", Entry."Document Type"::Order);
            Entry.SetRange("Document No.", DocumentNo);
            Entry.SetRange("Service Item Line No.", LineNo);
        end;
        if not Entry.FindFirst() then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', NotLentLbl));
        exit(true);
    end;

    local procedure MergeEntry(var Argument: Record "Message Argument ori"; var Entry: Record "Loaner Entry"; Candidate: Record "Loaner Entry"; Mode: Integer): Boolean
    begin
        if (Mode <> 0) and (Entry."Entry No." <> Candidate."Entry No.") then
            exit(Parser.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, '', ConflictLbl));
        Entry := Candidate;
        exit(true);
    end;

}
