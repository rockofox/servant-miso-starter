{
  description = "Haskell Servant + Miso full-stack template";

  inputs = {
    # Delegate the WASM toolchain through miso's own flake.
    miso.url = "github:dmjio/miso";
    nixpkgs.follows = "miso/nixpkgs";
    flake-utils.follows = "miso/flake-utils";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        hs = pkgs.haskellPackages;

        devScript = pkgs.writeShellScriptBin "dev" ''
          exec ${pkgs.hivemind}/bin/hivemind "$(git rev-parse --show-toplevel)/Procfile"
        '';

        myapp-api = hs.developPackage {
          root = ./myapp-api;
          name = "myapp-api";
        };

        myapp-server = hs.developPackage {
          root = ./myapp-server;
          name = "myapp-server";
          overrides = _final: _prev: { inherit myapp-api; };
        };
      in
      {
        packages = {
          inherit myapp-api myapp-server;
          default = myapp-server;
        };

        # Native dev shell. Backend and tooling.
        devShells.default = hs.shellFor {
          packages = _: [ myapp-api myapp-server ];
          buildInputs = with hs; [
            cabal-install
            ghcid
            hlint
            fourmolu
            haskell-language-server
          ] ++ [ pkgs.zlib pkgs.hivemind devScript ];
          shellHook = ''
            echo "myapp dev shell"
            echo ""
            echo "  dev            start backend + WASM watcher side-by-side (mprocs)"
            echo ""
            echo "  Or separately:"
            echo "    ghcid --command='cabal repl lib:myapp-server' \\"
            echo "          --reload=myapp-api/src --reload=myapp-server/src \\"
            echo "          --warnings --run=MyApp.Server.main"
            echo "    nix develop .#wasm  (then: ./scripts/build-ui.sh / ghciwatch ...)"
            echo ""
            echo "  Server + static files: http://localhost:8080"
          '';
        };

        # WASM dev shell. Delegated from miso.
        # Provides: wasm32-wasi-cabal, wasm32-wasi-ghc, wasi-sdk, wasm-opt, ghciwatch, http-server
        devShells.wasm = pkgs.mkShell {
          inputsFrom = [ inputs.miso.outputs.devShells.${system}.wasm ];
          shellHook = ''
            echo "WASM shell. Run './scripts/build-ui.sh' to build and copy artifacts to myapp-ui/static/"
          '';
        };
      }
    );
}
