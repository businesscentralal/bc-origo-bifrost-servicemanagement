# Extension: Bifrost Service Management

## Customer
Origo / AppSource

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.ServiceManagement` namespace; same as Bifrost Subscription Billing)

## Namespace
Origo.Bifrost.ServiceManagement (tests: Origo.Bifrost.ServiceManagement.Test)

## Object ID Range
App:   10076035-10076184
Tests: 97700-97799

Note: 10076035-10076134 was formerly claimed by the archived, never-released Cloud Events Orchestrator (`OrigoSoftwareSolutions/bc-cloudevents-orchestrator`); reused here by Gunnar's decision on 31.10.2026.

Allocated ids (record every new id here):

| Id | Object | Name |
| --- | --- | --- |
| 10076035 | codeunit | Svc Registration ori |
| 10076036 | permissionset | BIFROST Svc ori |
| 10076037 | permissionsetextension | BIFROST SvcFull ori |
| 10076038 | permissionsetextension | BIFROST SvcRead ori |
| 97700 | codeunit (test) | Svc Test Install ori |
| 97701 | codeunit (test) | Svc Test Upgrade ori |
| 97702 | codeunit (test) | Svc Registration Tst ori |
| 97703 | permissionset (test) | Svc Platform Tst ori |

## Microsoft source
Business Central Service Management (service orders, service items, service contracts, service quotes) lives in the **Base Application**; BC 28 has no separate Microsoft service app to depend on. Source: https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Service
`main` of BCApps is a newer release than BC 28.5; read the matching `releases/28.x` branch when you need the exact 28.5 source.
Read it there before designing message types.

## Setup Notifications
Setup notifications live **only** on Bifröst Foundation's `Setup ori` page. This app never raises a `Notification` of its own.
It makes itself known to Foundation by subscribing to `App Registry ori.OnRegisterApps` and calling `AddApp` with this
app's module id, its display name and its setup page id (`0` while the app has no setup page). Follow
`app/src/Common/SubRegistration.Codeunit.al` in Bifrost Subscription Billing.

## Target BC Version
28.5 (application 28.5.0.0, platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-servicemanagement
Default branch: main

## Dependencies
- Base Application (application floor 28.5.0.0)
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.5.590, same floor as Bifrost Subscription Billing)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters.
- The brand name "Bifrost" lives in the namespace, the app name ("Bifrost Service Management"), the permission sets and
  user-facing captions - never as an object-name prefix.
- Message type names have three parts: `Domain.Entity.Action`.
- Icelandic captions use "Bifröst".

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills: `origo-bc-al-coding-standards`, `origo-bc-test-writer`, `origo-bc-documentation-writer`.

Key rules always in effect:
- Namespace `Origo.Bifrost.ServiceManagement` at the top of every app file (`Origo.Bifrost.ServiceManagement.Test` in tests)
- XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- Implementation = code + tests + documentation (the contract chapters of `Msg Contract ori`)

## Development Environment
- COSMO Alpaca containers are defined in `app/.vscode/launch.json` (git-ignored, the authority for instance ids).
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop; AL-Go CI is the gate for AppSource affix rules (AS0011).
- `app/AppSourceCop.json` sets `mandatoryAffixes`/`mandatorySuffix` to `ori` and the supported countries.
- Reference implementation: Bifrost Subscription Billing (businesscentralal/bc-origo-bifrost-subscription-billing).

## Message Type Conventions
- One enum extension of Foundation's `Message Type ori` with one value per type, named `Domain.Entity.Action`. These
  keys are the published external API contract and must never be renamed or removed.
- Each type has an Impl codeunit implementing `Msg Interface ori`, `Msg Discovery ori` and `Msg Contract ori`, with
  `TableNo = "Message Argument ori"` and an `OnRun` that runs its own write, as in Bifrost Subscription Billing.
- Errors are returned as `status = Error` with a helpful message; never let an unhandled exception reach the API.

## Test App Rules
- The test app uses Bifröst Foundation's public API only. Run message types through the public `Dispatcher ori`.

## Testing Through the MCP Server
- Keep MCP calls serial - parallel bursts crash the server.

## Issue #4 shared lifecycle preparation

| Id | Object | Name |
| --- | --- | --- |
| 10076040 | codeunit | Svc Contract Parts ori |
| 10076041 | codeunit | Svc Document Lookup ori |
| 97704 | codeunit | Svc Test Data ori |
| 97711 | codeunit (test) | Svc Fixture Tests ori |
| 97712 | codeunit (test) | Svc Lookup Tests ori |

The shared lookup validates `no`, `systemId` and plain `subject`, and accepts the document
type from its caller. The fixture helper creates its own customer, service item, item and
resource lines through BC test libraries. The `SERVICEMGT` suite selects 97700..97799.

`Service.Order.Release` and `Service.Order.Reopen` are not registered by this preparation.
Issue #4 still requires Gunnar’s A1/A2 decisions, the lifecycle implementations, dispatcher
acceptance tests, localized contracts and current-tip native/UI/MCP verification.
The naming guard is available locally; Architect owns its SourceGuards workflow wiring.

Component tests (97712) verify only the shared lookup through the app’s internal helper and
Foundation’s public argument API. They do not replace the required public-dispatcher tests
for the eventual release/reopen message types.
