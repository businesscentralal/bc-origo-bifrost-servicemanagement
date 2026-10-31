namespace Origo.Bifrost.ServiceManagement;

using Origo.Bifrost;

/// <summary>
/// Makes Bifrost Service Management known to Bifrost Foundation's application registry.
/// Setup notifications - enabling outbound HTTP, missing credentials, running the setup wizard -
/// are shown only on Foundation's Bifrost Setup page, which aggregates them over every registered
/// application. This app therefore raises no notification of its own; it only answers the
/// registration event so Foundation can report on it.
/// The codeunit declares InherentPermissions and InherentEntitlements because Foundation builds the
/// registry while Bifrost Setup opens under the restricted licence administrator role, which holds
/// no Execute grant on this app. It only adds metadata to the temporary registry buffer.
/// </summary>
codeunit 10076035 "Svc Registration ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    /// <summary>
    /// Adds Bifrost Service Management to the registry that Foundation is building.
    /// </summary>
    /// <param name="Apps">The temporary registry buffer passed by the OnRegisterApps event.</param>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}
