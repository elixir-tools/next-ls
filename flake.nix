{
  inputs = {nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";};

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;

    # Helper to provide system-specific attributes
    forAllSystems = f:
      nixpkgs.lib.genAttrs (builtins.attrNames burritoExe) (system:
        f rec {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
          beamPackages = pkgs.beam.packages.erlang_26;
          elixir = beamPackages.elixir_1_15;
        });

    burritoExe = {
      "aarch64-darwin" = "darwin_arm64";
      "x86_64-darwin" = "darwin_amd64";
      "x86_64-linux" = "linux_amd64";
      "aarch64-linux" = "linux_arm64";
    };
  in {
    packages = forAllSystems ({
      pkgs,
      system,
      beamPackages,
      elixir,
    }: let
      aliased_7zz = pkgs.symlinkJoin {
        name = "7zz-aliased";
        paths = [pkgs._7zz];
        postBuild = ''
          ln -s ${pkgs._7zz}/bin/7zz $out/bin/7z
        '';
      };
    in rec {
      default = lib.makeOverridable ({
        localBuild,
        beamPackages,
        elixir,
      }:
        beamPackages.mixRelease rec {
          pname = "next-ls";
          version = "0.14.2"; # x-release-please-version
          src = self.outPath;
          inherit (beamPackages) erlang;
          inherit elixir;

          nativeBuildInputs = [pkgs.xz pkgs.zig_0_11 aliased_7zz];

          mixFodDeps = beamPackages.fetchMixDeps {
            inherit src version elixir;
            pname = "${pname}-deps";
            hash = "sha256-LV1DYmWi0Mcz1S5k77/jexXYqay7OpysCwOtUcafqGE=";
          };

          BURRITO_ERTS_PATH = "${beamPackages.erlang}/lib/erlang";
          BURRITO_TARGET = lib.optional localBuild burritoExe.${system};

          preBuild = ''
            export HOME="$tmpDir"
          '';

          postInstall = ''
            chmod +x ./burrito_out/*
            cp -r ./burrito_out "$out"
            ${lib.optionalString pkgs.stdenv.isLinux ''
              patchelf --set-interpreter ${pkgs.stdenv.cc.libc}/lib/${
                if system == "x86_64-linux"
                then "ld-linux-x86-64.so.2"
                else if system == "aarch64-linux"
                then "ld-linux-aarch64.so.1"
                else throw "unsupported Linux system"
              } \
              "$out/burrito_out/next_ls_${burritoExe.${system}}"
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
        }) {
        inherit beamPackages elixir;
        localBuild = true;
      };

      ci = default.override {localBuild = false;};
    });

    devShells = forAllSystems ({
      pkgs,
      beamPackages,
      elixir,
      ...
    }: {
      default = pkgs.mkShell {
        # The Nix packages provided in the environment
        packages = [beamPackages.erlang elixir];
      };
    });
  };
}
