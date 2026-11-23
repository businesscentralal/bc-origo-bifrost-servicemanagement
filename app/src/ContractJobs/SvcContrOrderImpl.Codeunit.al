namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Implements Service.Contract.CreateServiceOrders through the native service contract lifecycle.</summary>
codeunit 10076161 "Svc Contr Order Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks licensing, version and the write role before the isolated operation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Processor: Codeunit "Svc Contr Order Proc ori";
        WriteCheck: Codeunit "Svc Write Check ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Contract.CreateServiceOrders');
        Processor.Execute(Argument);
    end;

    /// <summary>Allows discovery without reading service data.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the service contract scope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Service Contract Header");
    end;

    /// <summary>Returns the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates preventive service orders for up to 200 confirmed service contracts.', Comment = 'is-IS=Stofnar fyrirbyggjandi þjónustupantanir fyrir allt að 200 staðfesta þjónustusamninga.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'service contract, recurring invoices, preventive maintenance, credit memo', Comment = 'is-IS=þjónustusamningur, reglulegir reikningar, fyrirbyggjandi viðhald, kreditreikningur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Returns the envelope help chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetEnvelope(Envelope, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the target help chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetTarget(Target, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the parameters help chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetParameters(Parameters, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the response help chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetResponse(Response, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the errors help chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetErrors(Errors, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the effect help chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetEffect(Effect, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the related help chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetRelated(Related, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the workflow help chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetWorkflow(Workflow, 'Orders');
        exit(true);
    end;

    /// <summary>Returns the examples help chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contr Job Help ori";
    begin
        Help.GetExamples(Examples, 'Orders');
        exit(true);
    end;

    /// <summary>Uses standard metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Explains transaction and retry behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The operation runs without prompts and rolls back on failure. Omit Commit preserves the caller transaction. Confirmation counts contracts, not documents. Re-read contracts and documents before retrying. No records are deleted. Invoice creation processes each contract separately, so invoices are not combined across the selected contracts.';
        exit(true);
    end;

    /// <summary>Describes the contract lifecycle.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Run periodic billing or preventive maintenance for confirmed signed contracts. Created invoices and credit memos remain unposted; review them before posting separately.';
        exit(true);
    end;
}
