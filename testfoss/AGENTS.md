# Testfoss demo guidance

Read `../durable-memory/index.md` before changing this additive demo.

## Boundaries

- Upstream Rerun source, examples, lockfiles, and existing workflows must remain byte-for-byte unchanged from `67f56ca049cb21fdada1110da95f6cd32528e68c`.
- In particular, keep `examples/js/viewer_control/src/main.ts` pristine and select the local recording through its existing `url` query parameter.
- Do not commit `node_modules`, Cargo or npm build products, screenshots, or LFS materialization changes.
- CI may materialize only `examples/assets/example.rrd` and `tests/assets/rerun.obj`, because those exact pinned fixtures are required by the demos.
- Preserve the MIT OR Apache-2.0 licensing and upstream notices.

## Commands

- `./testfoss/run.sh --check` checks shell, JavaScript, and LMScript syntax without compiling Rerun.
- `./testfoss/run.sh` builds the debug web viewer and multiview, runs the official viewer-control smoke test, and runs the lmwebtest browser scenario.
- `./testfoss/run.sh --browser-only` reuses an existing build.

The browser scenario must continue to invoke `lmwebtest playwright` through `cli="lmwebtest playwright"`.
Use WebGL with SwiftShader for headless testing.
Do not claim WebGPU support from this demo.
