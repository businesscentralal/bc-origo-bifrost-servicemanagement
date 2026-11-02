namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Shared identity and validation contract chapters for the service document lifecycle.</summary>
codeunit 10076040 "Svc Contract Parts ori"
{
    Access = Internal;

    /// <summary>Declares the plain-number subject alternative and JSON version 1.0 envelope.</summary>
    internal procedure GetEnvelope(var Envelope: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'documentNo');
        Subject.Add('description', 'Optional plain service document number. Every supplied identifier must agree.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Describes the shared service document identity alternatives.</summary>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.no', 'document no.', 'Service document number in the message type''s document scope.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Service Header SystemId. The document type must match the message type.'));
        Target.Add(Contract.TargetEntry('subject', 'document no.', 'Plain service document number, as an alternative to data.no.'));
    end;

    /// <summary>Declares the common optional identifiers, at least one of which must be supplied.</summary>
    internal procedure GetIdentityParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Service document number, at most 20 characters. Required unless systemId or plain subject is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonempty Service Header GUID. Every supplied identifier must identify the same document.'));
    end;

    /// <summary>Declares shared validation errors; operation-specific callers add their own business refusals.</summary>
    internal procedure GetIdentityErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No document identifier was supplied.', 'Send no, systemId or a plain subject.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'An identifier is empty, too long or identifies the wrong document type.', 'Use an identifier in the documented document scope.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An identifier is not a JSON string or systemId is not a GUID.', 'Correct the identifier type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The service document was not found.', 'Read Service Header with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different service documents.', 'Send identifiers belonging to the same document.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several declared parameters are invalid; nothing changed.', 'Correct each returned parameter error.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Foundation rejected an undeclared parameter before executing the message type.', 'Remove the undeclared parameter.'));
    end;
}
