{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      pname = "next-ls";
      version = "0.10.4"; # x-release-please-version
      src = ./.;

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      packages = forAllSystems ({ pkgs }:
        let
          beamPackages = pkgs.beam.packages.erlang_26;
        in {
          default = beamPackages.mixRelease {
            inherit pname version src;
            erlang = beamPackages.erlang;
            elixir = beamPackages.elixir_1_15;

            nativeBuildInputs = [pkgs.xz pkgs.zig_0_10 pkgs._7zz];

            mixFodDeps = beamPackages.fetchMixDeps {
              inherit src version;
              pname = "${pname}-deps";
              hash = "sha256-wweJ9+YuI+2ZdrWDgnMplAE7e538m1YoYRu8wKEPltQ=";
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

            postInstall = ''
              cp -r ./burrito_out "$out"
            '';
          };
      });

      devShells = forAllSystems ({ pkgs }:
        let
          beamPackages = pkgs.beam.packages.erlang_26;
        in {
          default = pkgs.mkShell {
          # The Nix packages provided in the environment
          packages = [
            beamPackages.erlang
            beamPackages.elixir_1_15
          ];
        };
      });
    };
}
