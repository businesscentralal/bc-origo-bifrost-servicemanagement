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
{"type":"Service.Quote.MakeOrder","data":{"no":"SQ000001"}}
```

Converts an accepted service quote with BC codeunit 5923, deletes the quote and returns the new order identity, customer, date and row counts. A plain `subject` or `data.systemId` can identify the quote; all supplied identifiers must agree. This call commits, even with Omit Commit. A retry after success returns `RecordNotFound`.

The effect is `write`: no confirmation is required, with or without Require Confirmation for Irreversible Messages. `expectedCount` is accepted and ignored for existing callers.

Allocations moved by BC with `Reallocation Needed` are counted in `allocationsToReallocate`; `nextStep` names `Service.Allocation.Allocate` when needed, otherwise `Service.Order.Release` / `Service.Order.Post`. Missing customer, bill-to customer or Service Order Nos. is `PreconditionFailed`. BC conversion errors are returned unchanged as `BusinessCentralError` and roll back the conversion.

The caller needs the Bifröst service write role and native service permissions. This type posts nothing and needs no posting token. Quote fields remain available through `Data.Records.Set`: conversion owns no field end to end. Contract quotes, archiving, loaners and chained operations are outside scope. Pre-merge Web Client acceptance remains `NOT_RUN (Premium)` per Gunnar's 02.11 decision; Tester checks English and Icelandic UI after deployment. Native and MCP evidence remain required before handoff.

Foundation dependency: published 28.0.11 (`28.0.11.669`), the first containing `Confirm Gate ori` and `Msg Confirm ori` (core #1151).

| Id | Object | Name |
| --- | --- | --- |
| 10076050 | enumextension | Svc Quote MsgType ori |
| 10076051 | codeunit | Svc Quote MakeOrder Impl ori |
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

Object ids: app 10076075–10076086, tests 97740–97750.

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
| 97750 | codeunit | Svc Post Caller Rollback ori |

## Service.Shipment.Undo and Service.Consumption.Undo (#20)

Undo posted service shipment lines (shipped, not consumed, not invoiced) or the consumption on posted service shipment lines (consumed, not invoiced) with the standard Business Central undo. Correcting entries are posted, correction lines are added to the posted shipment and the quantity returns to the service order line. Nothing is deleted.

```json
{"type":"Service.Shipment.Undo","data":{"documentNo":"SSH000001","lineNos":[10000],"expectedCount":1}}
{"type":"Service.Consumption.Undo","data":{"documentNo":"SSH000001","expectedCount":1}}
```

- `documentNo`, `systemId` (Service Shipment Header) or a plain subject; `lineNos` (1-200 distinct positive line numbers) or leave it out for every line that can be undone.
- `expectedCount` is 1: the posted shipment, not its lines. Without it the answer is `ConfirmationRequired` with the line list.
- Every requested line is checked before anything is posted. A shipment line whose shipment created service items is refused with `PreconditionFailed`, because the standard undo would delete those service items (Gunnar 20.11.2026, card `plan-sm-delete-paths` option a). Consumed lines need `Service.Consumption.Undo` first; invoiced lines need a service credit memo.
- Needs `BIFROST SvcPost ori` (checked before any line validation, also on the confirmation path). Commits on a normal call. With Omit Commit the standard undo does not commit: it stays in the caller's transaction and a later caller error rolls it back (regression 97751 with caller 97756).

Object ids: app 10076087–10076093, tests 97751–97756.

| Id | Object | Name |
| --- | --- | --- |
| 10076087 | enumextension | Svc Undo MsgType ori |
| 10076088 | codeunit | Svc Shipment Undo Impl ori |
| 10076089 | codeunit | Svc Undo Proc ori |
| 10076090 | codeunit | Svc Consumption Undo Impl ori |
| 10076091 | codeunit | Svc Undo Lines ori |
| 10076092 | codeunit | Svc Undo Confirm ori |
| 10076093 | codeunit | Svc Undo Contract ori |
| 97751 | codeunit (test) | Svc Undo Tests ori |
| 97752 | codeunit (test) | Svc Undo Perm Tests ori |
| 97753 | codeunit (test) | Svc Undo Contract Tests ori |
| 97754 | codeunit | Svc Undo Data ori |
| 97755 | codeunit | Svc Undo Perm Runner ori |
| 97756 | codeunit | Svc Undo Caller Rollback ori |
## Service.Order.AdjustPrice (#29)

Applies the fixed, maximum or minimum price of a service price group setup to the service lines of one service item line on a service order or quote, previews it (`preview: true`, nothing written) or restores the normal prices (`reset: true`, Business Central's own `ResetAdjustedLines`). Write; gated by the write gate, the read role is refused (preview included, issue question 2 recommendation).

```json
{"type":"Service.Order.AdjustPrice","data":{"documentNo":"SO000001","serviceItemLineNo":10000,"preview":true}}
{"type":"Service.Order.AdjustPrice","data":{"documentNo":"SO000001","serviceItemLineNo":10000,"reset":true}}
```

- Business Central applies the adjustment only behind a modal page. The type fills **temporary** `Service Line Price Adjmt.` rows (so the real table is never filled or cleared; R1), spreads the amount by weight and writes the prices with its own apply step (rewritten from the standard flow, status `Adjusted`). The last line takes the rounding difference so the lines add up to the target.
- `AdjustLines` is not called: it asks a confirmation and spreads on the record passed by value; the spread is rebuilt instead.
- Refusals: no service price group or no matching setup, no covered lines, invoiced lines, nothing to reset → `PreconditionFailed`; BC errors → `BusinessCentralError`, rolled back.
- `Price Adjmt. Status` stays open to `Data.Records.Set` (optional item of the issue not taken).

Object ids are an offset block (10076140–10076142, tests 97770–97773) because #24, #26 and #29 (wave 2) start in parallel.

| Id | Object | Name |
| --- | --- | --- |
| 10076140 | codeunit | Svc Price Adjust Impl ori |
| 10076141 | codeunit | Svc Price Adjust Proc ori |
| 10076142 | enumextension | Svc Price MsgType ori |
| 97770 | codeunit (test) | Svc Price Adjust Tests ori |
| 97771 | codeunit (test) | Svc Price Perm Tests ori |
| 97772 | codeunit (test) | Svc Price Contract Tests ori |
| 97773 | codeunit (test helper) | Svc Price Perm Runner ori |

## Service.FaultResolution.Suggest (#28)

Ranks the resolution codes that fixed the same fault before (table `Fault/Resol. Cod. Relationship`), most occurrences first. Read only; no confirmation and no gate. Gunnar 20.11.2026: Calculate is dropped (it deletes and rebuilds the table); the table is rebuilt in Business Central by the Insert Fault/Resol. Relations batch job.

```json
{"type":"Service.FaultResolution.Suggest","data":{"documentNo":"SO000001","serviceItemLineNo":10000,"top":5}}
{"type":"Service.FaultResolution.Suggest","data":{"faultCode":"NOPOWER","symptomCode":"DEAD"}}
```

- `Service Mgt. Setup`.`Fault Reporting Level` decides the filter: Fault (fault code), Fault+Symptom (+ symptom), Fault+Symptom+Area (+ fault area). None is `PreconditionFailed`.
- A line without the codes the level needs is `PreconditionFailed` with a `Data.Records.Set` next step; codes sent directly without them are `MissingParameter`. Line plus codes that disagree are `ConflictingIdentifiers`.
- A service item group returns rows for that group and rows without a group.
- The caller needs its own read access to `Service Item Line`, `Service Mgt. Setup` and `Fault/Resol. Cod. Relationship`; the type names the unreadable table in `PermissionDenied`. The standard `D365PREM SMG, VIEW` set does not include the relationship table; the Bifröst sets do not widen BC data access (AppSourceCop AS0110/AS0112).

Object ids are an offset block (10076120–10076121, tests 97790–97792) because #20, #22, #27 and #28 were started in parallel from 10076087.

| Id | Object | Name |
| --- | --- | --- |
| 10076120 | codeunit | Svc Fault Resol Suggest ori |
| 10076121 | enumextension | Svc Fault MsgType ori |
| 97790 | codeunit (test) | Svc Fault Suggest Tests ori |
| 97791 | codeunit (test) | Svc Fault Perm Tests ori |
| 97792 | codeunit (test) | Svc Fault Contract Tests ori |

## Service.Resource.Suggest (#27)

`Service.Resource.Suggest` is a read. For one service item line of a service order (`documentNo` + `serviceItemLineNo`, or the line `systemId`) and a period of at most 31 days (`dateFrom`, `dateTo`, default the work date), it ranks the resources: qualified first, then in the order service zone, then most available hours (capacity minus active, unposted service order allocations), then resource no. Optional `resourceGroupNo`, `includeUnqualified` (default false) and `top` (default 20, max 100). Qualification is Business Central's own `QualifiedForServiceItemLine`. When Resource Skills Option is Not Used, every resource is returned with `qualified` = null; when Service Zones Option is Not Used or the order has no zone, `inServiceZone` = null. Blocked resources are left out. Nothing is written, so there is no confirmation and no write gate; the type is in `BIFROST SvcRead ori`. A caller without native read access to service headers, service item lines, service setup, resources, skills, service zones, capacity or allocations gets `PermissionDenied` (a standard reader has `D365 READ`).

`Service.Dispatch.Get` is not built: the dispatch board is a plain read of `Service Header` (Document Type Order, sorted by Status, Response Date, Response Time, Priority, with `No. of Allocations` and `Reallocation Needed`), documented in the help as a `Data.Records.Get` recipe, as recommended in the issue (open question 2). Pre-merge Web Client UI: no UI change.

| Id | Object | Name |
| --- | --- | --- |
| 10076130 | enumextension | Svc Suggest MsgType ori |
| 10076131 | codeunit | Svc Resource Suggest Impl ori |
| 10076132 | codeunit | Svc Resource Suggest ori |
| 97780 | codeunit (test) | Svc Suggest Tests ori |
| 97781 | codeunit (test) | Svc Suggest Perm Tests ori |
| 97782 | codeunit (test) | Svc Suggest Contract Tests ori |
| 97783 | codeunit (test helper) | Svc Suggest Data ori |

Ids 10076130-10076132 and 97780-97783 were taken above the lowest free numbers because #20, #22 and #28 are built in parallel from the same range.

## Standalone service billing (#22)

```json
{"type":"Service.Invoice.GetShipmentLines","data":{"customerNo":"C0001","shipmentNos":["SS0001","SS0002"]}}
{"type":"Service.Document.PreviewPost","data":{"documentType":"Invoice","no":"SI0001"}}
{"type":"Service.Document.Post","data":{"documentType":"Invoice","no":"SI0001","expectedCount":1}}
{"type":"Service.Document.Post","data":{"documentType":"CreditMemo","no":"SCM0001","expectedCount":1}}
```

Collect shipped service lines on an open invoice, preview its entries, then post it. For an existing invoice use `invoiceNo`, `systemId` or a plain subject instead of `customerNo`. Select 1–200 distinct `shipmentNos`, or `allUninvoiced: true`. All selected shipments must match the invoice customer, bill-to customer and currency. Already invoiced, consumed, corrected or already added lines are skipped with a reason. `linesAdded` includes native shipment description lines.

`Service.Document.Post` and `Service.Document.PreviewPost` accept `documentType: Invoice | CreditMemo` and `no`, `systemId` or subject. Orders continue to use `Service.Order.Post` and `Service.Order.PreviewPost`. Posting needs `expectedCount: 1` and `BIFROST SvcPost ori`; the count is one document. Posting returns the posted number and systemId, customer, amounts and customer/G/L entry ranges. Preview returns ledger entries and rolls back every change. Shipment collection needs the Bifröst service write role and posts nothing.

Gunnar approved standard posting cleanup for this issue on 20 November 2026 (decision `d-20261120-sm22-post-cleanup`): successful posting removes the unposted invoice or credit memo. Preview cannot run with Omit Commit. Posting retains native commits. After an uncertain posting result, inspect posted documents before retrying. There is no page or action change.

| ID | Object | Name |
| --- | --- | --- |
| 10076094 | codeunit | Svc Doc Post Impl ori |
| 10076095 | codeunit | Svc Doc Post Proc ori |
| 10076096 | codeunit | Svc Doc Preview Impl ori |
| 10076097 | codeunit | Svc Doc Preview Proc ori |
| 10076098 | codeunit | Svc Doc Confirm ori |
| 10076099 | codeunit | Svc Doc Request ori |
| 10076100 | codeunit | Svc Doc Contract ori |
| 10076101 | codeunit | Svc Inv Shipment Impl ori |
| 10076102 | codeunit | Svc Inv Shipment Proc ori |
| 10076103 | enumextension | Svc Doc MsgType ori |
| 97757 | test codeunit | Svc Doc Tests ori |
| 97758 | test codeunit | Svc Doc Perm Tests ori |
| 97759 | test codeunit | Svc Doc Contract Tests ori |
| 97760 | codeunit | Svc Doc Fixture ori |
| 97761 | codeunit | Svc Doc Perm Runner ori |

## Service contract lifecycle (#24)

```json
{"type":"Service.ContractQuote.MakeContract","data":{"contractQuoteNo":"XQUOTE001","expectedCount":1,"createInvoice":false}}
{"type":"Service.Contract.Sign","data":{"contractNo":"XCONTRACT001","expectedCount":1,"createInvoice":false}}
{"type":"Service.Contract.Unlock","data":{"contractNo":"XCONTRACT001"}}
{"type":"Service.Contract.Lock","data":{"contractNo":"XCONTRACT001"}}
```

Conversion files and removes the quote, using Gunnar's 20 November conversion exception. Native conversion already creates a signed, locked contract with the same number. Sign also supports a separately created unsigned contract. Any initial invoice remains unposted; posting remains a separate permission-gated operation.

All four effects are `write`, following Gunnar's 21 November ruling in #43. The explicit single-contract count required by #24 AC03 is enforced for conversion and signing independently of Foundation's irreversible-effect default. Lock and Unlock require no count, and repeating the target change status is refused.

`createInvoice`, `acceptMissingServiceDate` and `acceptNonMonthEndInvoiceDate` default to true, matching BC's confirmation defaults. False declines the initial invoice or refuses the corresponding date condition before writing. `addLinesStartingLater` defaults to true; false refuses lines beginning after the contract starting date. The sign/convert action itself is confirmed by `expectedCount: 1`. Signed contracts with new lines require the native addendum workflow in the client before locking; these operations do not silently run that additional workflow. Native Status validation already refuses a direct transition to Signed. Generic Change Status writes are restricted with a Lock/Unlock hint.

The processor preserves Omit Commit, catches native failures at an isolated write boundary, and binds the invoice-choice subscriber only for the current operation. No UI objects change.

| ID | Object | Name |
| --- | --- | --- |
| 10076150 | codeunit | Svc Contract Make Impl ori |
| 10076151 | codeunit | Svc Contract Sign Impl ori |
| 10076152 | codeunit | Svc Contract Lock Impl ori |
| 10076153 | codeunit | Svc Contract Unlock Impl ori |
| 10076154 | enumextension | Svc Contract MsgType ori |
| 10076155 | codeunit | Svc Contract Proc ori |
| 10076156 | codeunit | Svc Contract Request ori |
| 10076157 | codeunit | Svc Contract Options ori |
| 10076158 | codeunit | Svc Contract Restrict ori |
| 10076159 | codeunit | Svc Contract Help ori |
| 97774 | codeunit | Svc Contract Data ori |
| 97775 | test codeunit | Svc Contract Lifecycle Tst ori |
| 97776 | test codeunit | Svc Contract Validate Tst ori |
| 97777 | test codeunit | Svc Contract Perm Tests ori |
| 97778 | test codeunit | Svc Contract Help Tests ori |
| 97779 | test permission set | Svc Contract Tst ori |

The app block 10076150–10076159 and test block 97774–97779 avoid the parallel wave-2 allocations in PR #45 (app 10076140–10076142, tests 97770–97773) and PR #46 (app 10076104–10076109, tests 97762–97766).

Contract callers need native contract editing and filing rights alongside the Bifröst full role. The role tests include native `Service Contract - Edit` through test fixture `Svc Contract Tst ori` (97779), avoiding the tenant-specific legacy role ID `SM-CONTRACT,EDIT`, and assert that `BIFROST SvcPost ori` is still absent; `D365PREM SMG, EDIT` alone does not grant insertion of filed contract lines. No native data permissions are added to the product permission sets.
