# Rerun Testfoss demo

This additive demo builds the official web viewer, `viewer_control` example, and renderer-only `multiview` example from the pinned source.
The upstream `viewer_control/src/main.ts` stays pristine: its existing `url` query parameter selects a loopback-served `example.rrd`.

## Run

Prerequisites are Bash, Git with Git LFS, Node.js 22.20.0, Pixi 0.82.1, Python 3, and `lmscript` 0.2.463 (`npm install -g @lmctl-ai/lmctl@0.2.463`).
Materialize only the two required pinned fixtures, then start the runner:

```sh
git lfs pull --include="examples/assets/example.rrd,tests/assets/rerun.obj"
./testfoss/run.sh
```

The full run executes `pixi run check-env`, `rerun-build-web`, the `multiview --build-only` build, `js-build-base-debug`, and the official `js-example-viewer-control-test` smoke test.
It then serves the Vite viewer, multiview output, and local recording on separate loopback ports and runs `scenario.lms` via `cli="lmwebtest playwright"`.
The scenario checks local Wasm and recording requests, play/pause, minimum and maximum seeks, the screenshot API, and a rendered multiview canvas.
Both applications use WebGL with SwiftShader.

For an existing build, use `./testfoss/run.sh --browser-only`.
For syntax checks without a build, use `./testfoss/run.sh --check`.
The `TESTFOSS_VIEWER_PORT`, `TESTFOSS_MULTIVIEW_PORT`, and `TESTFOSS_RECORDING_PORT` variables override ports 8102, 8103, and 8104.
Set `CHROME` to use an existing Chrome/Chromium executable instead of the pinned Playwright browser.
Generated logs and screenshots stay in the ignored `testfoss/.artifacts/` directory.

The cold debug viewer build took about 35 minutes in the source lab; the workflow therefore has a 120-minute timeout.
WebGPU is not claimed: the lab's SwiftShader WebGPU path failed, while WebGL passed.
The viewer's optional GitHub latest-release request is unrelated to recording playback and is not blocked.
CI has read-only repository permission, no secrets or deployment, and pinned actions.
Do not commit LFS materialization changes or generated build output.
