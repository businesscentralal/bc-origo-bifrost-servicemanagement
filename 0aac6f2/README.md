# PR9 CI runner repair evidence

Candidate: `0aac6f252987f0dd176c3989248a908a1e36d529` on `feat/4-service-order-lifecycle-worker8`.

The prior CI ran 42 tests: 41 passed, 1 failed, 0 skipped. AC12 starts a real session in an isolated ordinary company, which runner130450 forbids. The previous developer native pass used130451. The repair selects Microsoft's standard non-isolated runner130451 for this test app in Test mode and retains Alpaca execution/result checks, the complete suite and all assertions. Other apps and Default retain their runner. No AL source changed.

Default product (without IVT), Test product and test app each compile with CodeCop/UICop/AppSourceCop:0errors/0warnings. All13 local source/pipeline guards pass. `compile.json` records exact source SHA and package hashes. Compiler version and actual timestamps are in the logs. The symbol download used the retained developer container, not a shared or customer environment.

Fresh complete paired CI: https://github.com/businesscentralal/bc-origo-bifrost-servicemanagement/actions/runs/41383928777 . Native results remain pending until its actual Test receipt. This publication does not claim a current-tip native/MCP/UI pass, independent verification, review clearance, issue completion, merge or UAT.

UI remains NOT_RUN under Claude's explicit Premium licensing disposition: https://github.com/businesscentralal/bc-origo-bifrost-servicemanagement/issues/4#issuecomment-6567708384 . No agent assigned a licence or changed consent/trial state. The prior52/52 self-seeded MCP receipt applies to d10b3ed only; no message implementation was changed in this CI repair.

Development container f0b5efcc1df3 (worker8-service4-lifecycle-20261102) was restarted to download missing compiler symbols, then stopped again with readback. No BC fixture data was created by this repair. Its deployment remains the original developer candidate; no new deployment/provenance claim is made. Original CI container f0cd3fce6ee8 was removed by the workflow and independently returned404. The new CI owns its own paired environment and cleanup.

Original developer checkpoints and acceptance remain preserved. Dáinn(worker-7) owns this assigned CI repair; issue4 delivery still requires independent Claude current-tip verification, Grok clearance, eligible approval, Architect merge/deployment, Tester UAT and eventual owned-container closure.
