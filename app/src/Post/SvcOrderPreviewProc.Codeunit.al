namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Service.Document;
using Microsoft.Service.Posting;

/// <summary>Runs Service-Post in preview mode inside Business Central's posting preview boundary.</summary>
codeunit 10076082 "Svc Order Preview Proc ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        PreviewShip: Boolean;
        PreviewConsume: Boolean;
        PreviewInvoice: Boolean;

    /// <summary>Runs the preview and returns the handler holding the captured, rolled-back entries.</summary>
    /// <param name="ServiceHeader">The order to preview.</param>
    /// <param name="Ship">Preview the shipment.</param>
    /// <param name="Consume">Preview consumption.</param>
    /// <param name="Invoice">Preview the invoice.</param>
    /// <param name="PostingPreviewEventHandler">Receives the captured entries.</param>
    /// <param name="ErrorText">Receives the error text when the preview failed.</param>
    /// <returns>True when the preview captured its entries.</returns>
    internal procedure Preview(ServiceHeader: Record "Service Header"; Ship: Boolean; Consume: Boolean; Invoice: Boolean; var PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler"; var ErrorText: Text): Boolean
    var
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        Boundary: Codeunit "Svc Order Preview Proc ori";
    begin
        Boundary.SetOptions(Ship, Consume, Invoice);
        BindSubscription(Boundary);
        GenJnlPostPreview.SetContext(Boundary, ServiceHeader);
        ClearLastError();
        if GenJnlPostPreview.Run() then; // expected to fail with the preview's Error('') after capturing entries
        UnbindSubscription(Boundary);
        if not GenJnlPostPreview.IsSuccess() then begin
            ErrorText := GetLastErrorText();
            exit(false);
        end;
        GenJnlPostPreview.GetPreviewHandler(PostingPreviewEventHandler);
        exit(true);
    end;

    /// <summary>Stores the options the subscriber applies.</summary>
    internal procedure SetOptions(Ship: Boolean; Consume: Boolean; Invoice: Boolean)
    begin
        PreviewShip := Ship;
        PreviewConsume := Consume;
        PreviewInvoice := Invoice;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Preview", OnRunPreview, '', false, false)]
    local procedure OnRunPreview(var Result: Boolean; Subscriber: Variant; RecVar: Variant)
    var
        ServiceHeader: Record "Service Header";
        ServicePost: Codeunit "Service-Post";
    begin
        // Manual binding scopes this subscriber to the preview started by Preview().
        ServiceHeader := RecVar;
        ServicePost.SetPostingOptions(PreviewShip, PreviewConsume, PreviewInvoice);
        ServicePost.SetHideValidationDialog(true);
        ServicePost.SetPreviewMode(true);
        Result := ServicePost.Run(ServiceHeader);
    end;
}
