# Service Management issue 4 — developer evidence

Candidate: `d10b3edbf2d9041e9b9fb1bd5cb789304dc25688`. Owner: Þráinn (worker-8).

Both app and test compile with CodeCop/UICop/AppSourceCop: **0 errors, 0 warnings**. Full configured native suite: **42 executed, 42 passed, 0 failed, 0 skipped**. Native client session en-US; dedicated language assertions exercise 1033 and 1039. Self-seeded MCP: **52 executed, 52 passed, 0 failed, 0 skipped**, both touched types in 1033/1039. Owned BC28.5 W1 container `f0b5efcc1df3`; exact deployed product/test source and package hashes in `read-provenance-tests.txt`.

UI: **NOT_RUN, 0 passed** because the standard Premium experience change refused the unlicensed user. [Claude scoped disposition](https://github.com/businesscentralal/bc-origo-bifrost-servicemanagement/issues/4#issuecomment-6567708384) says this gap does not block handover; it is not a pass or waiver. Gunnar decision `d-20261102-servicemanagement-premium-ui` pending. Base UI Icelandic coverage is not claimed.

AC01–15 have developer evidence. AC16 independent Claude bc29-w1 receipt, AC17 normal Default/Test CI, AC18 same-SHA postmerge Tester UAT remain pending. See the per-AC matrix. Local naming guard including SelfTest and all eleven source guards passed; no SourceGuards workflow wiring is included (Architect issue 8).

All test fixtures were self-created. The native suite ran through standard runner 130451 (Test Isolation Disabled) to permit its real background-session EULA refusal test; no test method was disabled. An ordinary unconsented test company produced EULA_REQUIRED and was removed, without consent/licence/trial writes. Verification companies were removed by standard BC administration and checked absent; global licence probe count is zero. Container is retained for postmerge closure, then stopped.

Foundation 28.0.11.643 generic primary-key validation order requires a temporary same-number empty Quote while inserting an Order Service Item Line. These owned Quotes served wrong-type tests and were cleaned with the verification company. The wider finding is disclosed separately; this PR changes no Foundation source.

Native logs and normalized MCP receipts are evidence, not independent Claude clearance or UAT approval. Historical failed runs remain in the retained private checkpoint; this directory records the passing current candidate.
