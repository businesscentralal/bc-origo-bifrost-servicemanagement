# Bifröst Service Management

**App name:** Bifrost Service Management
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `f74e6852-7965-4c14-afb7-1102e080cda7` — **Test app ID:** `d39af77f-6b49-426f-a2ba-830ec3f35e21`
**Object ID range:** 10076035–10076184 (tests 97700–97799) — **Namespace:** `Origo.Bifrost.ServiceManagement`

Bifrost Service Management will make the Service Management area of Business Central callable from outside Business Central
through Bifröst message types: service orders, service items, service quotes, resource allocation and service posting, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Layers/W1/BaseApp/Service> (Service Management is part of the Base Application)

**Status:** planning, no message types yet.

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
| `app/` | The AppSource app (`Bifrost Service Management`), registration and permission sets, no message types yet |
| `test/` | Test app (`Bifrost Service Management - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

## Issue #4 shared lifecycle preparation

| Id | Object | Name |
| --- | --- | --- |
| 10076040 | codeunit | Svc Contract Parts ori |
| 10076041 | codeunit | Svc Document Lookup ori |
| 97704 | codeunit | Svc Test Data ori |
| 97711 | codeunit (test) | Svc Fixture Tests ori |

The shared lookup validates `no`, `systemId` and plain `subject`, and accepts the document
type from its caller. The fixture helper creates its own customer, service item, item and
resource lines through BC test libraries. The `SERVICEMGT` suite selects 97700..97799.

`Service.Order.Release` and `Service.Order.Reopen` are not registered by this preparation.
Issue #4 still requires Gunnar’s A1/A2 decisions, the lifecycle implementations, dispatcher
acceptance tests, localized contracts and current-tip native/UI/MCP verification.
The naming guard is available locally; Architect owns its SourceGuards workflow wiring.
