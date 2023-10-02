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
      version = "0.14.0"; # x-release-please-version
      src = ./.;

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        f {
          inherit pkgs;
          # src = pkgs.fetchFromGitHub {
          #   owner = "elixir-tools";
          #   repo = "next-ls";
          #  rev = "v${version}";
          #  sha256 = "sha256-jpOInsr7Le0fjJZToNNrlNyXNF1MtF1kQONXdC2VsV0=";
          # };
          system = system;
        });

      burritoExe = system:
        if system == "aarch64-darwin" then
          "darwin_arm64"
        else if system == "x86_64-darwin" then
          "darwin_amd64"
        else if system == "x86_64-linux" then
          "linux_amd64"
        else if system == "aarch64-linux" then
          "linux_arm64"
        else
          "";
    in
    {
      packages = forAllSystems ({ pkgs, system }:
        let
          beamPackages = pkgs.beam.packages.erlang_26;
          build = type: beamPackages.mixRelease {
            inherit pname version src;
            erlang = beamPackages.erlang;
            elixir = beamPackages.elixir_1_15;

            nativeBuildInputs = [ pkgs.xz pkgs.zig_0_10 pkgs._7zz ];

            mixFodDeps = beamPackages.fetchMixDeps {
              inherit src version;
              pname = "${pname}-deps";
              hash = "sha256-sRve0L7qFw5vEsespIXVg4loSej+oLO1ewdmT6qGExw=";
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
              if type == "local" then ''
                export BURRITO_TARGET="${burritoExe(system)}"
              ''
              else "";

            postInstall = ''
              chmod +x ./burrito_out/*
              cp -r ./burrito_out "$out"

              if [ "${system}" == "x86_64-linux" ]; then
                patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 "$out/burrito_out/next_ls_linux_amd64"
              fi
            '';
          };
        in
        {
          default = build ("local");
          ci = build ("ci");
        });

      apps = forAllSystems ({ pkgs, system, ... }: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/burrito_out/next_ls_${burritoExe(system)}";
        };
      });

      devShells = forAllSystems ({ pkgs, ... }:
        let
          beamPackages = pkgs.beam.packages.erlang_26;
        in
        {
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
