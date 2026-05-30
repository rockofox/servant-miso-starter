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

        wasmShell = inputs.miso.outputs.devShells.${system}.wasm;
        wasmTools = wasmShell.inputDerivation.nativeBuildInputs ++ wasmShell.inputDerivation.buildInputs;

        mkApp = program: {
          type = "app";
          program = pkgs.lib.getExe program;
        };

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

        # Build the Miso WASM frontend into myapp-ui/static/, then shrink with wasm-opt.
        buildUi = pkgs.writeShellApplication {
          name = "build-ui";
          runtimeInputs = wasmTools;
          text = ''
            wasm32-wasi-cabal update
            wasm32-wasi-cabal build --project-file=cabal.project.ui myapp-ui
            wasm_bin="$(wasm32-wasi-cabal list-bin --project-file=cabal.project.ui myapp-ui | tail -n 1)"
            libdir="$(wasm32-wasi-ghc --print-libdir)"
            "$libdir/post-link.mjs" --input "$wasm_bin" --output myapp-ui/static/ghc_wasm_jsffi.js
            cp -v "$wasm_bin" myapp-ui/static/app.wasm
            wasm-opt -O3 --strip-debug myapp-ui/static/app.wasm -o myapp-ui/static/app.wasm
            echo "WASM artifacts written to myapp-ui/static/ ($(du -sh myapp-ui/static/app.wasm | cut -f1))"
          '';
        };

        # Static files laid out at the in-image path used by MYAPP_STATIC_DIR.
        # Note: the WASM artifacts must be built via `nix run .#build-ui` and
        # committed into myapp-ui/static/ before `nix build` will bake them in
        # (Nix's pure source filter only sees git-tracked files).
        staticFilesImage = pkgs.runCommand "myapp-static-image" { } ''
          mkdir -p $out/opt/myapp/static
          cp -r ${./myapp-ui/static}/. $out/opt/myapp/static/
        '';

        # ----- Backend OCI image (Nix-built; deps come from the binary cache) -----
        serverImageConfig = {
          Cmd = [ "myapp-server" ];
          Env = [
            "MYAPP_STATIC_DIR=/opt/myapp/static"
            "MYAPP_PORT=8080"
            "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            "PATH=/bin"
          ];
          ExposedPorts = {
            "8080/tcp" = { };
          };
          WorkingDir = "/opt/myapp";
        };

        serverImageContents = [
          myapp-server
          pkgs.cacert
          staticFilesImage
        ];

        myapp-server-image-stream = pkgs.dockerTools.streamLayeredImage {
          name = "ghcr.io/rockofox/servant-miso-starter/myapp-server";
          tag = "latest";
          contents = serverImageContents;
          config = serverImageConfig;
        };

        myapp-server-image = pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/rockofox/servant-miso-starter/myapp-server";
          tag = "latest";
          contents = serverImageContents;
          config = serverImageConfig;
        };
      in
      {
        packages = {
          inherit myapp-api myapp-server;
          "build-ui" = buildUi;
          inherit myapp-server-image myapp-server-image-stream;
          default = myapp-server;
        };

        apps = {
          "build-ui" = mkApp buildUi;
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
