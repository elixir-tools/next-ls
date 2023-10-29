{
  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # Helper to provide system-specific attributes
      forAllSystems = f:
        nixpkgs.lib.genAttrs (builtins.attrNames burritoExe) (system:
          f rec {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
            beamPackages = pkgs.beam.packages.erlang_25;
            elixir = beamPackages.elixir_1_15;
          });

      burritoExe = {
        "aarch64-darwin" = "darwin_arm64";
        "x86_64-darwin" = "darwin_amd64";
        "x86_64-linux" = "linux_amd64";
        "aarch64-linux" = "linux_arm64";
      };
    in {
      packages = forAllSystems ({ pkgs, system, beamPackages, elixir }:
        let
          build = type:
            beamPackages.mixRelease rec {
              pname = "next-ls";
              version = "0.14.2"; # x-release-please-version
              src = self.outPath;
              inherit (beamPackages) erlang;
              inherit elixir;

              nativeBuildInputs = [ pkgs.xz pkgs.zig_0_11 pkgs._7zz ];

              mixFodDeps = beamPackages.fetchMixDeps {
                inherit src version;
                pname = "${pname}-deps";
                hash = "sha256-LCY9ClMG/hP9xEciZUg+A6NQ8V3K7mM2l+6D+WZcubM=";
              };

              preConfigure = ''
                bindir="$(pwd)/bin"
                mkdir -p "$bindir"
                echo '#!/usr/bin/env bash
                7zz "$@"' > "$bindir/7z"
                chmod +x "$bindir/7z"

                export HOME="$(pwd)"
                export PATH="$bindir:$PATH"
              '';

              preBuild = ''
                export BURRITO_ERTS_PATH=${beamPackages.erlang}/lib/erlang
              '';

              preInstall =
                lib.optionalString (type == "local") ''
                  export BURRITO_TARGET="${burritoExe.${system}}"
                '';

              postInstall = ''
                chmod +x ./burrito_out/*
                cp -r ./burrito_out "$out"
                ${lib.optionalString (system == "x86_64-linux") ''
                  patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
                    "$out/burrito_out/next_ls_linux_amd64"
                ''}
                rm -rf "$out/bin"
                mv "$out/burrito_out" "$out/bin"
                mv "$out/bin/next_ls_${burritoExe.${system}}" "$out/bin/nextls"
              '';

              meta = with lib; {
                license = licenses.mit;
                homepage = "https://www.elixir-tools.dev/next-ls/";
                description = "The language server for Elixir that just works";
                mainProgram = "nextls";
              };
            };
        in {
          default = build ("local");
          ci = build ("ci");
        });

      devShells = forAllSystems ({ pkgs, beamPackages, elixir, ... }:
        {
          default = pkgs.mkShell {
            # The Nix packages provided in the environment
            packages = [ beamPackages.erlang elixir ];
          };
        });
    };
}
