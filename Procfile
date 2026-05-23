backend: ghcid --command='cabal repl lib:myapp-server' --reload=myapp-api/src --reload=myapp-server/src --warnings --run=MyApp.Server.main
ui: nix develop .#wasm --command bash -c 'ghciwatch --command="wasm32-wasi-cabal repl --project-file=cabal.project.ui myapp-ui" --watch myapp-api/src --watch myapp-ui/app --after-startup-shell ./scripts/build-ui.sh --after-reload-shell ./scripts/build-ui.sh'
