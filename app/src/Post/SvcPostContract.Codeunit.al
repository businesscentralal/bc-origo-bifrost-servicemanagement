namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>Contract chapters shared by Service.Order.Post and Service.Order.PreviewPost.</summary>
codeunit 10076086 "Svc Post Contract ori"
{
    Access = Internal;

    /// <summary>Declares the order identity and the ship, consume and invoice options.</summary>
    internal procedure GetParameters(var Parameters: JsonArray)
    var
        Parts: Codeunit "Svc Contract Parts ori";
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parts.GetIdentityParameters(Parameters);
        Parameters.Add(Contract.Parameter('ship', 'boolean', false, 'Post the shipment (Qty. to Ship on the lines). When none of ship, consume and invoice is sent, ship and invoice are both true. A flag that is not sent is false once another flag is sent.'));
        Parameters.Add(Contract.Parameter('consume', 'boolean', false, 'Post consumption (Qty. to Consume). Only together with ship = true, never with invoice. Default false.'));
        Parameters.Add(Contract.Parameter('invoice', 'boolean', false, 'Post the invoice (Qty. to Invoice). Send invoice alone to invoice what was shipped.'));
    end;

    /// <summary>Declares the errors both types can answer.</summary>
    internal procedure GetErrors(var Errors: JsonArray; Preview: Boolean)
    var
        Parts: Codeunit "Svc Contract Parts ori";
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parts.GetIdentityErrors(Errors);
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'consume with invoice, consume without ship, or all three flags false.', 'The four combinations of the Business Central posting menu are Ship, Invoice, Ship and Invoice, and Ship and Consume.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'ship, consume or invoice is not a JSON boolean (null, a string or a number).', 'Send true or false, or leave the key out.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'There is nothing to post, or the service invoice posting policy of the user does not allow the combination.', 'Set Qty. to Ship, Qty. to Consume or Qty. to Invoice on the lines with Data.Records.Set; ask an administrator to check User Setup.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the posting (missing posting setup, closed period, blocked customer, item tracking); its text is returned and nothing was posted.', 'Correct the Business Central error and retry.'));
        if Preview then
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Preview needs its own transaction and cannot run under Omit Commit.', 'Run the preview without Omit Commit.'))
        else begin
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Posting denied: the caller lacks the BIFROST SvcPost ori permission set.', 'Ask an administrator to assign BIFROST SvcPost ori.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'expectedCount (1) was not sent.', 'Send expectedCount 1.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount differs from the one order selected.', 'Send expectedCount 1.'));
        end;
    end;

    /// <summary>Declares the related message types.</summary>
    internal procedure GetRelated(var Related: JsonArray; Preview: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Preview then
            Related.Add(Contract.RelatedEntry('Service.Order.Post', 'You want to post for real.'))
        else
            Related.Add(Contract.RelatedEntry('Service.Order.PreviewPost', 'You want to see the entries first.'));
        Related.Add(Contract.RelatedEntry('Service.Order.Release', 'The order must be released for warehouse handling.'));
        Related.Add(Contract.RelatedEntry('Service.Allocation.Allocate', 'Allocate a resource before service starts.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Set Qty. to Ship, Qty. to Consume and Qty. to Invoice on the service lines.'));
    end;

    /// <summary>Declares the service job workflow.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    var
        Parts: Codeunit "Svc Contract Parts ori";
    begin
        Parts.GetServiceWorkflow(Workflow);
    end;

    /// <summary>Describes the keywords shared by the examples of the Post type.</summary>
    internal procedure PostExamples(var Examples: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        PostedShipInvoice: Text;
    begin
        PostedShipInvoice := '{"status":"Success","documentNo":"SVC-ORDER1","customerNo":"10000","customerName":"Adatum","ship":true,"consume":false,"invoice":true,"postedDocuments":[{"type":"Service Shipment","no":"SVC-SHIP1"},{"type":"Service Invoice","no":"SVC-INV1"}],"serviceLedgerEntries":2,"orderDeleted":true,"lines":[]}';
        Examples.Add(Contract.Example('Ship and invoice (default)', '{"type":"Service.Order.Post","data":{"no":"SVC-ORDER1","expectedCount":1}}', PostedShipInvoice));
        Examples.Add(Contract.Example('Ship only', '{"type":"Service.Order.Post","data":{"no":"SVC-ORDER1","ship":true,"expectedCount":1}}', '{"status":"Success","documentNo":"SVC-ORDER1","ship":true,"consume":false,"invoice":false}'));
        Examples.Add(Contract.Example('Invoice what was shipped', '{"type":"Service.Order.Post","data":{"no":"SVC-ORDER1","invoice":true,"expectedCount":1}}', '{"status":"Success","documentNo":"SVC-ORDER1","ship":false,"consume":false,"invoice":true}'));
        Examples.Add(Contract.Example('Ship and consume', '{"type":"Service.Order.Post","data":{"no":"SVC-ORDER1","ship":true,"consume":true,"expectedCount":1}}', '{"status":"Success","documentNo":"SVC-ORDER1","ship":true,"consume":true,"invoice":false}'));
    end;
}
