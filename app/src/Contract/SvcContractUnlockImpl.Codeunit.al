namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Service.Contract;
using Origo.Bifrost;

/// <summary>Implements Service.Contract.Unlock through the native service contract lifecycle.</summary>
codeunit 10076143 "Svc Contract Unlock Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        Processor: Codeunit "Svc Contract Proc ori";
        WriteCheck: Codeunit "Svc Write Check ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Service.Contract.Unlock');
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
        DescriptionLbl: Label 'Opens a service contract for changes. Use Service.Contract.Lock to lock it again.', Comment = 'is-IS=Opnar þjónustusamning fyrir breytingum. Notaðu Service.Contract.Lock til að læsa honum aftur.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'service contract, contract quote, sign, lock, unlock', Comment = 'is-IS=þjónustusamningur, samningstilboð, undirrita, læsa, opna';
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
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetEnvelope(Envelope, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the target help chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetTarget(Target, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the parameters help chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetParameters(Parameters, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the response help chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetResponse(Response, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the errors help chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetErrors(Errors, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the effect help chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetEffect(Effect, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the related help chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetRelated(Related, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the workflow help chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetWorkflow(Workflow, 'Unlock');
        exit(true);
    end;

    /// <summary>Returns the examples help chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Help: Codeunit "Svc Contract Help ori";
    begin
        Help.GetExamples(Examples, 'Unlock');
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
        Notes := 'The native operation runs without prompts. Failed operations roll back. Omit Commit keeps the caller transaction. Conversion files and removes the quote and already signs the contract; retrying the removed quote returns RecordNotFound. Locking a signed contract with new lines requires the native addendum workflow in the client.';
        exit(true);
    end;

    /// <summary>Describes the contract lifecycle.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Convert an accepted contract quote, or sign an existing unsigned contract. Unlock a contract to edit it, then lock it again. Any invoice created remains unposted.';
        exit(true);
    end;
}
