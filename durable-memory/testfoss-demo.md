# Testfoss demo

## Provenance

The fork branch is `testfoss-demo`, based on upstream Rerun `67f56ca049cb21fdada1110da95f6cd32528e68c`.
The isolated source-build lab recorded build provenance and Playwright acceptance on 2026-11-08 at the same source pin.
The lab patched `viewer_control/src/main.ts` for its local default recording, but this fork deliberately does not carry that patch.
The fork uses the pristine file's existing `url` query parameter instead.

The lab used Pixi 0.82.1, Rust 1.98.1, wasm-bindgen 0.2.129, Node.js 22.20.0, and Chrome 157 through Playwright.
The fork pins `lmwebtest` to `2920befd355eacc654697820d690db074e94dce3` and invokes its Playwright host with LMScript 0.2.463.

## Lab-proven commands

```sh
pixi run check-env
pixi run rerun-build-web
pixi run re-renderer-web-example multiview --build-only
pixi run js-example-viewer-control -- -- --port 8102 --host 127.0.0.1 --strictPort
CHROME=/usr/bin/google-chrome pixi run js-example-viewer-control-test
python3 -m http.server 8103 --bind 127.0.0.1 --directory target/wasm/re_renderer_examples/multiview
```

The full debug viewer build passed and took 2,103 seconds in the lab.
The official viewer-control Playwright smoke test passed once in 15.5 seconds.
The lab verified local viewer and multiview Wasm, local `example.rrd`, play/pause, seeks to 0 and 3990000000, a 1024-pixel screenshot API result, and one multiview canvas rendering four scenes.
The required recording is `examples/assets/example.rrd` with SHA-256 `f1becccbde64dc4bdb7223400d017758f3e408b6ad7f048f255cbf77c8e28888`.
The required multiview mesh is `tests/assets/rerun.obj` with SHA-256 `994cde777d23e0a3c1de9f7e508b9d9c087ae402178380a454b673928e83c752`.
CI materializes only those two LFS fixtures and never commits their materialization diffs.

## Fork workflow

`testfoss/run.sh` reproduces the source builds and official smoke test, starts Vite, multiview, and a same-origin recording proxy, and runs `testfoss/scenario.lms` through `lmwebtest playwright`.
The proxy serves the hash-checked fixture at `/example.rrd` and forwards every other request to Vite, matching the official smoke test without an upstream TypeScript change.
The workflow uses read-only repository permission and SHA-pinned actions, with no deployment or secrets.
Exact local commands and browser-only reuse are documented in `testfoss/README.md`.

## Limitations

Primary WebGPU failed in the lab on SwiftShader with a `GPUDevice.createBuffer` error for both viewer and multiview.
The viewer follows the official default renderer; `TESTFOSS_DISABLE_WEBGPU=1` is an explicit fallback, and multiview forces WebGL. No native-GPU or WebGPU support is claimed. Playback waits for play/pause event completion before capture, matching the official smoke test's synchronization and 1280×720 viewport.
The lab observed winit's intentional `Using exceptions for control flow` page error in multiview; only that exact known message is tolerated by the new smoke check.
The full debug source build is tested, not a release build.
The viewer may still make its optional GitHub latest-release request, but recording playback does not use `app.rerun.io`.
Multiview PNG capture timed out once under SwiftShader, matching a lab-observed limitation, so the scenario asserts the rendered canvas, local Wasm, WebGL backend, and page errors without requiring that capture.
The expensive build was not repeated while authoring this additive content.
The new scenario passed all 15 lmwebtest checks against the existing lab-built upstream servers and a loopback recording server with `/usr/bin/google-chrome`; the viewer screenshot visually confirmed the local DNA recording.
Fresh-install schema discovery and syntax checks also passed, while the full source build and Actions run remain CI validation.
