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
| 97725 | codeunit (test) | Svc Allocation Tests ori |
| 97726 | codeunit (test) | Svc Reallocation Tests ori |
| 97727 | codeunit (test) | Svc Alloc Restrict Tests ori |
| 97728 | codeunit (test) | Svc Alloc Contract Tests ori |
| 97729 | codeunit (test) | Svc Alloc Perm Tests ori |
| 10076060 | enumextension | Svc Alloc MsgType ori |
| 10076061 | codeunit | Svc Allocation Impl ori |
| 10076062 | codeunit | Svc Allocation Proc ori |
| 10076063 | codeunit | Svc Alloc Check ori |
| 10076064 | codeunit | Svc Alloc Restrict ori |

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
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.11.669, same floor as Bifrost Subscription Billing)

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

## Issue #4 service order lifecycle

`Service.Order.Release` releases an open service order for warehouse handling.
`Service.Order.Reopen` reopens a released service order. Both use standard BC routines,
refuse requests that would repeat the current state, and preserve Omit Commit.
They accept `no`, `systemId`, or a plain `subject`. Every supplied identifier must agree.
Quotes, invoices and credit memos are outside this order-only scope.

```json
{"no":"SO000001"}
```

Responses include order identity, customer, `releaseStatusBefore`, `releaseStatusAfter`,
`amount` and `amountIncludingVAT`. States are `Open` and `ReleasedToShip`.
`Data.Records.Set` cannot change `Service Header`.`Release Status`; use the dedicated
operations. Ordinary fields and reads remain available. Contract chapters are available
through `Help.Implementation.Get` / `describe_message_type`.

| Id | Object | Name |
| --- | --- | --- |
| 97700 | codeunit | Svc Test Install ori |
| 97701 | codeunit | Svc Test Upgrade ori |
| 97702 | codeunit | Svc Registration Tst ori |
| 97703 | permissionset | Svc Platform Tst ori |
| 97704 | codeunit | Svc Test Data ori |
| 97705 | codeunit | Svc Order Release Tests ori |
| 97706 | codeunit | Svc Order Reopen Tests ori |
| 97707 | codeunit | Svc Release Restrict Tests ori |
| 97708 | codeunit | Svc Release Contract Tests ori |
| 97709 | codeunit | Svc Release Perm Tests ori |
| 97710 | permissionset | Svc NoGrant Tst ori |
| 97711 | codeunit | Svc Fixture Tests ori |
| 97712 | codeunit | Svc Lookup Tests ori |
| 97713 | table | Svc Licence Result Tst ori |
| 97714 | codeunit | Svc Licence Probe Tst ori |
| 10076035 | codeunit | Svc Registration ori |
| 10076036 | permissionset | BIFROST Svc ori |
| 10076037 | permissionsetextension | BIFROST SvcFull ori |
| 10076038 | permissionsetextension | BIFROST SvcRead ori |
| 10076039 | enumextension | Svc Release MsgType ori |
| 10076040 | codeunit | Svc Contract Parts ori |
| 10076041 | codeunit | Svc Document Lookup ori |
| 10076042 | codeunit | Svc Order Release Impl ori |
| 10076043 | codeunit | Svc Order Reopen Impl ori |
| 10076044 | codeunit | Svc Release Proc ori |
| 10076045 | codeunit | Svc Release Restrict ori |
| 10076060 | enumextension | Svc Alloc MsgType ori |
| 10076061 | codeunit | Svc Allocation Impl ori |
| 10076062 | codeunit | Svc Allocation Proc ori |
| 10076063 | codeunit | Svc Alloc Check ori |
| 10076064 | codeunit | Svc Alloc Restrict ori |
| 97725 | codeunit | Svc Allocation Tests ori |
| 97726 | codeunit | Svc Reallocation Tests ori |
| 97727 | codeunit | Svc Alloc Restrict Tests ori |
| 97728 | codeunit | Svc Alloc Contract Tests ori |
| 97729 | codeunit | Svc Alloc Perm Tests ori |

## Issue #6 service allocation

`Service.Allocation.Allocate` allocates or reallocates a resource on a service order item line. It accepts `documentNo`, `systemId`, `entryNo` or a plain `subject`. `allocatedHours` is required. Send `resourceNo` or `resourceGroupNo`. An active entry is moved with `SetHideDialog` so no modal page runs. Cancellation is not supported. Orders only.

Object ids 10076065–10076074 and test ids 97730–97739 are reserved. Pre-merge Web Client UI is not run here: Service Management UI needs a Premium licence and is UAT after deployment (issue comment 6576452597). That is `NOT_RUN`, not a pass.

The shared lookup and contract parts support the subsequent service lifecycle stories.
Native tests use self-created fixtures and the public Foundation dispatcher; the
`SERVICEMGT` suite selects 97700..97799. Lookup component tests remain separate from
message acceptance. The naming guard runs locally; workflow wiring belongs to
Architect's issue #8. Runtime, Claude receipt, CI and UAT results belong in exact-SHA
verification evidence, not inferred from this source inventory.

## Service.Quote.MakeOrder (#5)

```json
{"type":"Service.Quote.MakeOrder","data":{"no":"SQ000001","expectedCount":1}}
```

Converts an accepted service quote with BC codeunit 5923, deletes the quote and returns the new order identity, customer, date and row counts. A plain `subject` or `data.systemId` can identify the quote; all supplied identifiers must agree. This call commits, even with Omit Commit, and cannot be undone. A retry after success returns `RecordNotFound`.

Call without `expectedCount` to obtain `ConfirmationRequired` with count 1 and the quote summary, then confirm that count. An administrator may turn required confirmation off per company; any supplied count is still validated. A wrong count returns `ConfirmationMismatch` without converting the quote.

Allocations moved by BC with `Reallocation Needed` are counted in `allocationsToReallocate`; `nextStep` names `Service.Allocation.Allocate` when needed, otherwise `Service.Order.Release` / `Service.Order.Post`. Missing customer, bill-to customer or Service Order Nos. is `PreconditionFailed`. BC conversion errors are returned unchanged as `BusinessCentralError` and roll back the conversion.

The caller needs the Bifröst service write role and native service permissions. This type posts nothing and needs no posting token. Quote fields remain available through `Data.Records.Set`: conversion owns no field end to end. Contract quotes, archiving, loaners and chained operations are outside scope. Pre-merge Web Client acceptance remains `NOT_RUN (Premium)` per Gunnar's 02.11 decision; Tester checks English and Icelandic UI after deployment. Native and MCP evidence remain required before handoff.

Foundation dependency: published 28.0.11 (`28.0.11.669`), the first containing `Confirm Gate ori` and `Msg Confirm ori` (core #1151).

| Id | Object | Name |
| --- | --- | --- |
| 10076050 | enumextension | Svc Quote MsgType ori |
| 10076051 | codeunit | Svc Quote MakeOrder Impl ori |
| 10076052 | codeunit | Svc Confirm ori |
| 97716 | codeunit (test) | Svc Quote Confirm Tests ori |
| 97717 | codeunit (test) | Svc Quote Contract Tests ori |
| 97718 | codeunit (test) | Svc Quote Perm Tests ori |
| 97719 | codeunit (test) | Svc Quote MakeOrder Tests ori |

Story test id 97715 was already occupied on main by `Svc Wrong Type Tests ori` (#10). Quote conversion uses 97719 from #5's reserved range, preserving the existing object.

`Service.Order.Post` is named as the planned next step in help. It is emitted in the structured `related` chapter only once issue #7 registers that type; Foundation rejects unknown related message names. This avoids the circular #5 → #7 → #5 source dependency.

| 97720 | codeunit (test helper) | Svc Quote Caller Rollback ori |

The caller-rollback regression verifies that Omit Commit conversion remains committed while a later unrelated caller write rolls back.

## Service.Order.Post and Service.Order.PreviewPost (#7)

Post a service order (ship, consume, invoice) and preview the entries first.

```json
{"type":"Service.Order.PreviewPost","data":{"no":"SO000001"}}
{"type":"Service.Order.Post","data":{"no":"SO000001","ship":true,"consume":true,"expectedCount":1}}
```

- Options: Ship, Invoice, Ship and Invoice (default when no flag is sent) and Ship and Consume. `consume` only with `ship`, never with `invoice`. The user's service invoice posting policy applies.
- Set `Qty. to Ship`, `Qty. to Consume` and `Qty. to Invoice` on the lines with `Data.Records.Set`. The posted-quantity fields are refused there.
- Post commits (Business Central's own commit in `Service-Post` is kept) and needs the permission set `BIFROST SvcPost ori`, which is not part of `BIFROST SvcFull ori` or `BIFROST SvcRead ori`. PreviewPost is listed only for holders of that set.

Object ids: app 10076075–10076086, tests 97740–97749.

| Id | Object | Name |
| --- | --- | --- |
| 10076075 | table | Svc Posting ori |
| 10076076 | permissionset | BIFROST SvcPost ori |
| 10076077 | enumextension | Svc Post MsgType ori |
| 10076078 | codeunit | Svc Posting Gate ori |
| 10076079 | codeunit | Svc Order Post Impl ori |
| 10076080 | codeunit | Svc Order Post Proc ori |
| 10076081 | codeunit | Svc Order Preview Impl ori |
| 10076082 | codeunit | Svc Order Preview Proc ori |
| 10076083 | codeunit | Svc Post Options ori |
| 10076084 | codeunit | Svc Post Restrict ori |
| 10076085 | codeunit | Svc Post Confirm ori |
| 10076086 | codeunit | Svc Post Contract ori |
| 97740–97745 | codeunit (test) | Svc Order Post / Preview / Post Confirm / Posting Gate / Post Restrict / Post Contract Tests ori |
| 97746 | codeunit (test) | Svc Post Lifecycle Tests ori |
| 97747 | codeunit (test) | Svc Post Licence Tests ori |
| 97748 | codeunit | Svc Post Licence Probe ori |
| 97749 | codeunit (test) | Svc Post Data ori |
