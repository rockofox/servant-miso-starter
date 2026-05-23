#!/usr/bin/env bash
set -euo pipefail
wasm32-wasi-cabal update
wasm32-wasi-cabal build --project-file=cabal.project.ui myapp-ui
wasm_bin="$(wasm32-wasi-cabal list-bin --project-file=cabal.project.ui myapp-ui | tail -n 1)"
libdir="$(wasm32-wasi-ghc --print-libdir)"
"$libdir/post-link.mjs" --input "$wasm_bin" --output myapp-ui/static/ghc_wasm_jsffi.js
cp "$wasm_bin" myapp-ui/static/app.wasm
echo "WASM artifacts written to myapp-ui/static/"
