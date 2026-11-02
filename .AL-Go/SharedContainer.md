# Sequential Default and Test builds

CI/CD and pull request builds create one COSMO Alpaca Default container per project.
`_BuildSharedALGoProject.yaml` runs Default before Test, in separate runner sessions.
Test must reuse the physical container ID returned by Default.

Default retains its release artifact, signing settings and previous-release upgrade checks.
Test recompiles **Bifrost Service Management** (`f74e6852-7965-4c14-afb7-1102e080cda7`) with the internals grant for
its test extension (`d39af77f-6b49-426f-a2ba-830ec3f35e21`), republishes that compiled app before the test
extension, and skips previous-release upgrade deployment. Dependency app IDs and versions
remain unchanged. Final cleanup runs after both phases, including failure and cancellation.

Run `./tools/Test-SharedAlpacaContainer.ps1` to check build-plan validation, mode and
container identity, republish ordering, missing-grant rejection and Default publishing.
The workflows run this check before building. Changes to the helper scripts trigger a full build.
If the container was removed, rerun all jobs rather than the Test phase alone.

The Service Management test app uses Microsoft's standard non-isolated runner 130451.
Its AC12 consent-refusal test creates and deletes its own ordinary company and starts a
background session there; the codeunit-isolated runner 130450 prohibits starting that session.
The wrapper retains Alpaca's test execution and result validation, all test methods and failure
gates. Other test apps and Default keep their existing runner.

AL-Go system updates may overwrite the custom workflow and initialization hooks. Preserve
the sequential wrapper, Default-only container creation plan, deferred cleanup, physical
container check, compiled test grant check and the existing internals-stripping hooks.
The helper validates the pinned Alpaca initialization before changing container selection;
incompatible upstream changes fail instead of silently selecting a different container.

Reference: Foundation PR #932 and merged build
https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core/actions/runs/37544940349.
