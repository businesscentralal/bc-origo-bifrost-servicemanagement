# Bifröst Service Management

**App name:** Bifrost Service Management
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `f74e6852-7965-4c14-afb7-1102e080cda7` — **Test app ID:** `d39af77f-6b49-426f-a2ba-830ec3f35e21`
**Object ID range:** 10076035–10076184 (tests 97700–97799) — **Namespace:** `Origo.Bifrost.ServiceManagement`

Bifrost Service Management will make the Service Management area of Business Central callable from outside Business Central
through Bifröst message types: service orders, service items, service quotes, resource allocation and service posting, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Service> (Service Management is part of the Base Application)

**Status:** service allocation and service order release/reopen are implemented. Allocation verification is tracked in issue #6. Release/reopen verification is tracked in issue #4.

---

## Object ranges

| Object | Range |
| --- | --- |
| App (`app/`) | 10076035-10076184 |
| Test app (`test/`) | 97700-97799 |

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://docs.bifrost.origo.is>.

| What | Where |
| --- | --- |
| Product documentation | <https://docs.bifrost.origo.is/en-us/service-management/> |
| Bifröst documentation home | <https://docs.bifrost.origo.is> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.11.669 |
| Base Application | | Microsoft | 28.5.0.0 (application floor) |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Service Management`), registration, permission sets and service order release/reopen |
| `test/` | Test app (`Bifrost Service Management - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

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

## Issue #6 service allocation

`Service.Allocation.Allocate` allocates a resource or resource group to a service item line of a service order for a date and a number of hours, or moves an active allocation to another resource. It uses standard Business Central allocation and does not commit on its own. Cancellation is not offered. Quotes, invoices and credit memos are outside this order-only scope.

```json
{"documentNo":"SO000001","resourceNo":"LINA","allocatedHours":2}
```

When Service Zones Option is Warning Displayed, a resource outside the order zone is refused unless `acceptOutsideServiceZone` is true. `Data.Records.Set` cannot change `Service Order Allocation` Status, Resource No. or Resource Group No.

| Id | Object | Name |
| --- | --- | --- |
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

Object ids 10076065–10076074 and test ids 97730–97739 are reserved for this story.

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
| 97715 | codeunit | Svc Wrong Type Tests ori |
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

Native conversion may calculate Item availability. The caller needs its standard base permissions for that calculation (the test fixture uses `D365 READ`; indirect-only `D365 ITEM AVAIL CALC` is insufficient for its FlowFields) as well as service editing. The Bifröst permission set grants no additional native table access. The read-role regression keeps these same native permissions and must still refuse conversion.

## Service.Order.Post and Service.Order.PreviewPost (#7)

Post a service order (ship, consume, invoice) and preview the entries first.

```json
{"type":"Service.Order.PreviewPost","data":{"no":"SO000001"}}
{"type":"Service.Order.Post","data":{"no":"SO000001","ship":true,"consume":true,"expectedCount":1}}
```

- Options: Ship, Invoice, Ship and Invoice (default when no flag is sent) and Ship and Consume. `consume` only with `ship`, never with `invoice`. The user's service invoice posting policy applies.
- Set `Qty. to Ship`, `Qty. to Consume` and `Qty. to Invoice` on the lines with `Data.Records.Set`. The posted-quantity fields are refused there.
- In an AL Omit Commit chain, native posting errors propagate unchanged so the caller can roll back. Normal calls return `BusinessCentralError` JSON. A successful post retains BC commits in both modes.
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
| 10076140 | codeunit | Svc Contract Make Impl ori |
| 10076141 | codeunit | Svc Contract Sign Impl ori |
| 10076142 | codeunit | Svc Contract Lock Impl ori |
| 10076143 | codeunit | Svc Contract Unlock Impl ori |
| 10076144 | enumextension | Svc Contract MsgType ori |
| 10076145 | codeunit | Svc Contract Proc ori |
| 10076146 | codeunit | Svc Contract Request ori |
| 10076147 | codeunit | Svc Contract Options ori |
| 10076148 | codeunit | Svc Contract Restrict ori |
| 10076149 | codeunit | Svc Contract Help ori |
| 97763 | codeunit | Svc Contract Data ori |
| 97764 | test codeunit | Svc Contract Lifecycle Tst ori |
| 97765 | test codeunit | Svc Contract Validate Tst ori |
| 97766 | test codeunit | Svc Contract Perm Tests ori |
| 97767 | test codeunit | Svc Contract Help Tests ori |

The app block starts at 10076140 to avoid the independent wave-2 issue allocations below it.

Contract callers need native contract editing and filing rights alongside the Bifröst full role. The role tests use `SM-CONTRACT,EDIT` and assert that `BIFROST SvcPost ori` is still absent; `D365PREM SMG, EDIT` alone does not grant insertion of filed contract lines. No native data permissions are added to the product permission sets.
