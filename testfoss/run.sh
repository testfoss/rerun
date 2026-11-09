#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
UPSTREAM_REV="67f56ca049cb21fdada1110da95f6cd32528e68c"
MODE="${1:-}"
VIEWER_PORT="${TESTFOSS_VIEWER_PORT:-8102}"
MULTIVIEW_PORT="${TESTFOSS_MULTIVIEW_PORT:-8103}"
RECORDING_PORT="${TESTFOSS_RECORDING_PORT:-8104}"
ARTIFACTS="$HERE/.artifacts"
SERVER_PIDS=()

cleanup() {
    for pid in "${SERVER_PIDS[@]:-}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
    for pid in "${SERVER_PIDS[@]:-}"; do
        [[ -n "$pid" ]] && wait "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

verify_upstream() {
    git -C "$ROOT" merge-base --is-ancestor "$UPSTREAM_REV" HEAD || {
        echo "The pinned upstream revision is not an ancestor of HEAD." >&2
        exit 1
    }
    git -C "$ROOT" diff --quiet "$UPSTREAM_REV" -- \
        . ':(exclude)README.md' ':(exclude)AGENTS.md' ':(exclude)durable-memory' \
        ':(exclude)testfoss' ':(exclude).github/workflows/testfoss.yml' || {
        echo "A non-allowlisted path differs from the pinned upstream revision." >&2
        exit 1
    }
}

wait_ready() {
    local url="$1"
    for _ in {1..120}; do
        if curl --fail --silent --output /dev/null "$url"; then
            return 0
        fi
        sleep 1
    done
    echo "Server did not become ready: $url" >&2
    return 1
}

chrome_path() {
    (cd "$HERE" && node --input-type=module -e "import { chromium } from 'playwright'; console.log(chromium.executablePath())")
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        shasum -a 256 "$1" | cut -d ' ' -f 1
    fi
}

verify_fixture() {
    local filename="$1"
    local expected="$2"
    [[ -f "$filename" ]] || {
        echo "Missing required LFS fixture: $filename" >&2
        exit 1
    }
    [[ "$(sha256 "$filename")" == "$expected" ]] || {
        echo "LFS fixture is not materialized or has the wrong hash: $filename" >&2
        echo "Run: git lfs pull --include=examples/assets/example.rrd,tests/assets/rerun.obj" >&2
        exit 1
    }
}

for tool in git node npm curl lmscript; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Required tool is not on PATH: $tool" >&2
        exit 1
    }
done
verify_upstream
bash -n "$HERE/run.sh"
node --check "$HERE/static-server.mjs"
export PATH="$HERE/node_modules/.bin:$PATH"
npm ci --prefix "$HERE"
lmscript -e 'let host_schema = load_schema(cli="lmwebtest playwright");'
lmscript --check "$HERE/scenario.lms"

if [[ "$MODE" == "--check" ]]; then
    exit 0
fi
if [[ "$MODE" != "" && "$MODE" != "--browser-only" ]]; then
    echo "Usage: $0 [--check|--browser-only]" >&2
    exit 2
fi

CHROME_PATH="${CHROME:-$(chrome_path)}"
if [[ ! -x "$CHROME_PATH" ]]; then
    [[ -z "${CHROME:-}" ]] || {
        echo "CHROME is not executable: $CHROME_PATH" >&2
        exit 1
    }
    npm exec --prefix "$HERE" -- playwright install chromium
fi
export CHROME="$CHROME_PATH"
verify_fixture "$ROOT/examples/assets/example.rrd" "f1becccbde64dc4bdb7223400d017758f3e408b6ad7f048f255cbf77c8e28888"
verify_fixture "$ROOT/tests/assets/rerun.obj" "994cde777d23e0a3c1de9f7e508b9d9c087ae402178380a454b673928e83c752"

if [[ "$MODE" != "--browser-only" ]]; then
    command -v pixi >/dev/null 2>&1 || {
        echo "Required build tool is not on PATH: pixi" >&2
        exit 1
    }
    export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}"
    pixi run --manifest-path "$ROOT/pixi.toml" check-env
    pixi run --manifest-path "$ROOT/pixi.toml" rerun-build-web
    pixi run --manifest-path "$ROOT/pixi.toml" re-renderer-web-example multiview --build-only
    pixi run --manifest-path "$ROOT/pixi.toml" js-build-base-debug
    (
        cd "$ROOT/examples/js/viewer_control"
        npm ci
        CHROME="$CHROME_PATH" npm test -- --retries=1
    )
fi

MULTIVIEW_DIST="$ROOT/target/wasm/re_renderer_examples/multiview"
for artifact in "$ROOT/rerun_js/web-viewer/re_viewer_bg.wasm" "$MULTIVIEW_DIST/index.html" "$MULTIVIEW_DIST/multiview_bg.wasm" "$ROOT/examples/js/viewer_control/node_modules/vite/bin/vite.js"; do
    [[ -f "$artifact" ]] || {
        echo "Missing build output $artifact; run without --browser-only first." >&2
        exit 1
    }
done
mkdir -p "$ARTIFACTS"
(
    cd "$ROOT/examples/js/viewer_control"
    exec node node_modules/vite/bin/vite.js --port "$VIEWER_PORT" --host 127.0.0.1 --strictPort
) >"$ARTIFACTS/viewer-server.log" 2>&1 &
SERVER_PIDS+=("$!")
node "$HERE/static-server.mjs" "$MULTIVIEW_DIST" "$MULTIVIEW_PORT" >"$ARTIFACTS/multiview-server.log" 2>&1 &
SERVER_PIDS+=("$!")
node "$HERE/static-server.mjs" "$ROOT/examples/assets" "$RECORDING_PORT" >"$ARTIFACTS/recording-server.log" 2>&1 &
SERVER_PIDS+=("$!")
wait_ready "http://127.0.0.1:$VIEWER_PORT/"
wait_ready "http://127.0.0.1:$MULTIVIEW_PORT/"
wait_ready "http://127.0.0.1:$RECORDING_PORT/example.rrd"
TESTFOSS_VIEWER_URL="http://127.0.0.1:$VIEWER_PORT" \
    TESTFOSS_MULTIVIEW_URL="http://127.0.0.1:$MULTIVIEW_PORT" \
    TESTFOSS_RECORDING_URL="http://127.0.0.1:$RECORDING_PORT/example.rrd" \
    TESTFOSS_ARTIFACTS="$ARTIFACTS" lmscript "$HERE/scenario.lms"
verify_upstream
