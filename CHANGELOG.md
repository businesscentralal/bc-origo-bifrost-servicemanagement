# Changelog

## Unreleased

### Added
- Add `Service.Order.Post` (irreversible, commits, `expectedCount` 1) and `Service.Order.PreviewPost` (read) through standard Business Central service posting (`Service-Post`, `Gen. Jnl.-Post Preview`): ship, invoice, ship and invoice (default), ship and consume, the user's service invoice posting policy, a posting token table `Svc Posting ori` (10076075) with the assignable set `BIFROST SvcPost ori` (10076076, not in Full or Read), a write guard for the six posted-quantity fields of `Service Line`, and bilingual contracts (10076075–10076086) (#7). Add posting, preview, confirmation, gate, write-guard and contract coverage (97740–97745, helper 97749). Builds on the `Svc Confirm ori` pattern of #5.
- Add quote-specific bilingual lookup refusals (10076041) and a 1039 regression (97719), keeping machine-readable expected `Quote` invariant.
- Add `Service.Quote.MakeOrder` with native quote conversion, shared confirmation, irreversible commit semantics, allocation reallocation counts, the existing service write-role guard and bilingual contracts (10076050–10076052); require published Foundation 28.0.11.669 (#5). Add quote conversion, confirmation, contract/licence and permission coverage (97716–97720), including an actual caller-rollback/Omit Commit regression; extend the owned-company licence probe (97714) and add actual Change Log configuration for self-seeded MCP fixtures (97704), retaining the write guard. Test 97719 preserves the already allocated 97715.
- Add `Service.Allocation.Allocate` (10076060–10076064) to allocate or reallocate a resource or resource group on a service order item line through standard Business Central allocation, without a modal page or its own `Commit`. Orders only. An outside service zone is refused unless `acceptOutsideServiceZone` is true when Service Zones Option is Warning Displayed. Generic writes of Status, Resource No. and Resource Group No. stay on this message type.
- Add allocation, reallocation, write-guard, contract, permission and unlicensed-company coverage (97725–97729). The licence probe (97714) also calls allocate. UI acceptance stays with Tester UAT because Service Management needs a Premium licence.
- Add `Service.Order.Release` and `Service.Order.Reopen` (10076039, 10076042–10076045) with standard BC execution, order-only lookup, rollback, bilingual catalogues/refusals and a field-level generic-write guard.
- Add public-dispatcher lifecycle, write-guard, contract, permission and unlicensed-company regression coverage (97705–97710, 97713–97714), with isolated self-created fixtures and no consent writes.

### Fixed
- Refuse `Service.Order.Release`, `Service.Order.Reopen` and `Service.Allocation.Allocate` for a caller without `BIFROST Svc ori` or `BIFROST Full ori`, through the new write gate table `Svc Write Gate ori` (10076065) and check `Svc Write Check ori` (10076066) (#14). Standard D365 permission sets grant codeunit Execute broadly. A read-only Bifrost user with D365 BASIC and service edit rights could therefore run these types once the Premium licence allowed the Service tables. `BIFROST SvcRead ori` grants only read on the gate. Add gate coverage to 97709; the read-role denial assertions in 97709 and 97729 are unchanged.
- Name the actual service document type in a wrong-type refusal by the base application caption in the caller's language (10076041). `Service.Order.Release` and `Service.Order.Reopen` keep `code`, `parameter` and the English `expected` name unchanged (97715).

### Changed
- Run the Service Management CI suite with standard runner 130451 so the new-company consent refusal test (97708) can start its real background session; retain every test and propagate Alpaca test failures.
- Record runner 130451 on the SERVICEMGT suite (97700) so a command-line run uses that same runner.
- Prepare issue #4 shared service document lookup and contract primitives (10076040–10076041), isolated lifecycle fixtures (97704), and fixture and lookup component regressions (97711–97712). The lifecycle implementations reuse these shared components.
- Correct the SERVICEMGT test selection range to 97700..97799 and service permission documentation.
- Add the core message-name guard for local verification; workflow wiring remains Architect-owned.


- Scaffold: registration with Bifrost Foundation's application registry (`Svc Registration ori`), permission set `BIFROST Svc ori` with the Foundation role extensions `BIFROST SvcFull ori` and `BIFROST SvcRead ori`, Icelandic translation file, and a test app smoke (`Svc Registration Tst ori`, own test suite SERVICEMGT). No message types yet.

## [28.0.0.0]

- Repository scaffolded from Bifrost Subscription Billing setup.
