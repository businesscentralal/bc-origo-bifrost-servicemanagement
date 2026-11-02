# Bifröst Service Management

**App name:** Bifrost Service Management
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `f74e6852-7965-4c14-afb7-1102e080cda7` — **Test app ID:** `d39af77f-6b49-426f-a2ba-830ec3f35e21`
**Object ID range:** 10076035–10076184 (tests 97700–97799) — **Namespace:** `Origo.Bifrost.ServiceManagement`

Bifrost Service Management will make the Service Management area of Business Central callable from outside Business Central
through Bifröst message types: service orders, service items, service quotes, resource allocation and service posting, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Service> (Service Management is part of the Base Application)

**Status:** service order release/reopen implementation; verification is tracked in issue #4.

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
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.5.590 |
| Base Application | | Microsoft | 28.5.0.0 (application floor) |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Service Management`), registration, permission sets and service order release/reopen |
| `test/` | Test app (`Bifrost Service Management - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

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

The shared lookup and contract parts support the subsequent service lifecycle stories.
Native tests use self-created fixtures and the public Foundation dispatcher; the
`SERVICEMGT` suite selects 97700..97799. Lookup component tests remain separate from
message acceptance. The naming guard runs locally; workflow wiring belongs to
Architect's issue #8. Runtime, Claude receipt, CI and UAT results belong in exact-SHA
verification evidence, not inferred from this source inventory.
