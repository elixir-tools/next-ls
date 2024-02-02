{
  inputs = {nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";};

  nixConfig = {
    extra-substituters = ["https://elixir-tools.cachix.org"];
    extra-trusted-public-keys = ["elixir-tools.cachix.org-1:GfK9E139Ysi+YWeS1oNN9OaTfQjqpLwlBaz+/73tBjU="];
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;

    version = "0.16.1"; # x-release-please-version

    # Helper to provide system-specific attributes
    forAllSystems = f:
      nixpkgs.lib.genAttrs (builtins.attrNames burritoExe) (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam_minimal.packages.erlang_26;
        elixir = beamPackages.elixir_1_15;
      in
        f {inherit system pkgs beamPackages elixir;});

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
    in {
      default = lib.makeOverridable ({
        localBuild,
        beamPackages,
        elixir,
      }:
        beamPackages.mixRelease {
          pname = "next-ls";
          src = self.outPath;
          inherit version elixir;
          inherit (beamPackages) erlang;

          nativeBuildInputs = [pkgs.xz pkgs.zig_0_11 aliased_7zz];

          mixFodDeps = beamPackages.fetchMixDeps {
            src = self.outPath;
            inherit version elixir;
            pname = "next-ls-deps";
            hash = "sha256-HyXsbQFlodvL8lL2ULI14IWNBprhm6dIwKuKUK0Doz4=";
          };

          BURRITO_ERTS_PATH = "${beamPackages.erlang}/lib/erlang";
          BURRITO_TARGET = lib.optional localBuild burritoExe.${system};

          preBuild = ''
            export HOME="$tmpDir"
          '';

          postInstall = ''
            chmod +x ./burrito_out/*
            cp -r ./burrito_out "$out"
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

      ci = self.packages.${system}.default.override {localBuild = false;};
    });

    devShells = forAllSystems ({
      pkgs,
      beamPackages,
      elixir,
      ...
    }: {
      default = pkgs.mkShell {
        # The Nix packages provided in the environment
        packages = [pkgs.zsh beamPackages.erlang elixir pkgs.xz pkgs.zig_0_11 pkgs._7zz pkgs.starship];
      };
    });
  };
}
