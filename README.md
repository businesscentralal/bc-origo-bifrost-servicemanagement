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

Native conversion may calculate Item availability. The caller needs its standard base permissions for that calculation (the test fixture uses `D365 READ`; indirect-only `D365 ITEM AVAIL CALC` is insufficient for its FlowFields) as well as service editing. The Bifröst permission set grants no additional native table access. The read-role regression keeps these same native permissions and must still refuse conversion.

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
