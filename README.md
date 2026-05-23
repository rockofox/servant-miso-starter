# servant-miso-starter

A minimal Nix-first template for a full-stack Haskell app:

- **Backend**: [Servant](https://docs.servant.dev/) on Warp
- **Frontend**: [Miso](https://haskell-miso.org/) compiled to WebAssembly via GHC's WASM backend
- **Shared types**: a tiny `myapp-api` package that both sides import. Change a type once, fail to compile on both sides

## Prerequisites

NixOS / Nix with flakes enabled. That's it. GHC, the WASM toolchain, cabal,
`ghciwatch`, everything else comes from the flake.

## Quick start

```sh
direnv allow   # or: nix develop
dev            # watches backend + frontend, serves on :8080
```

Then open <http://localhost:8080>.

`dev` runs both watchers via [hivemind](https://github.com/DarthSim/hivemind).
Ctrl+C kills everything cleanly.

## Dev workflow

### All-in-one

```sh
dev
```

### Separately (two terminals)

**Terminal 1 (backend):**
```sh
nix develop
ghcid --command='cabal repl lib:myapp-server' \
      --reload=myapp-api/src --reload=myapp-server/src \
      --warnings --run=MyApp.Server.main
```

**Terminal 2 (WASM UI):**
```sh
nix develop .#wasm
ghciwatch \
  --command='wasm32-wasi-cabal repl --project-file=cabal.project.ui myapp-ui' \
  --watch myapp-api/src --watch myapp-ui/app \
  --after-startup-shell ./scripts/build-ui.sh \
  --after-reload-shell ./scripts/build-ui.sh
```

### One-off builds

```sh
# Native packages (api + server)
nix build

# WASM UI. Must be run inside the WASM shell.
nix develop .#wasm
./scripts/build-ui.sh
```

## Environment

| Var                | Default           | Purpose                   |
|--------------------|-------------------|---------------------------|
| `MYAPP_PORT`       | `8080`            | Server bind port          |
| `MYAPP_STATIC_DIR` | `myapp-ui/static` | Directory served on `Raw` |

## Renaming the project

Pick a name (e.g. `widget`), then from the repo root:

```sh
# rename module references and project name
find . -type f \
  \( -name '*.hs' -o -name '*.cabal' -o -name 'cabal.project*' \
  -o -name 'flake.nix' -o -name '*.md' -o -name '*.html' -o -name '*.js' \) \
  -not -path './.git/*' -not -path './dist-newstyle/*' \
  -exec sed -i 's/MyApp/Widget/g; s/myapp/widget/g; s/MYAPP/WIDGET/g' {} +

# rename package directories
git mv myapp-api    widget-api
git mv myapp-server widget-server
git mv myapp-ui     widget-ui

# rename module directories
mv widget-api/src/MyApp    widget-api/src/Widget    2>/dev/null || true
mv widget-server/src/MyApp widget-server/src/Widget 2>/dev/null || true
mv widget-ui/app/MyApp     widget-ui/app/Widget     2>/dev/null || true
```

Then rename the `.cabal` files to match (`myapp-api.cabal` → `widget-api.cabal`, etc.).
