namespace Origo.Bifrost.ServiceManagement;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Service.Document;
using Microsoft.Service.Posting;

/// <summary>Runs Service-Post in preview mode inside Business Central's posting preview boundary.</summary>
codeunit 10076097 "Svc Doc Preview Proc ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    /// <summary>Runs the preview and returns the handler holding the captured, rolled-back entries.</summary>
    /// <param name="ServiceHeader">The invoice or credit memo to preview.</param>
    /// <param name="PostingPreviewEventHandler">Receives the captured entries.</param>
    /// <param name="ErrorText">Receives the error text when the preview failed.</param>
    /// <returns>True when the preview captured its entries.</returns>
    internal procedure Preview(ServiceHeader: Record "Service Header"; var PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler"; var ErrorText: Text): Boolean
    var
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        Boundary: Codeunit "Svc Doc Preview Proc ori";
    begin
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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Preview", OnRunPreview, '', false, false)]
    local procedure OnRunPreview(var Result: Boolean; Subscriber: Variant; RecVar: Variant)
    var
        ServiceHeader: Record "Service Header";
        ServicePost: Codeunit "Service-Post";
    begin
        // Manual binding scopes this subscriber to the preview started by Preview().
        ServiceHeader := RecVar;
        // Let native initialization derive document-specific options after collecting lines.
        // Invoice=true here would prematurely remove unshipped credit memo lines.
        ServicePost.SetPostingOptions(false, false, false);
        ServicePost.SetHideValidationDialog(true);
        ServicePost.SetPreviewMode(true);
        Result := ServicePost.Run(ServiceHeader);
    end;
}
