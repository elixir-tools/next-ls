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
        beam = fetchTarball {
          url = "https://beam-machine-universal.b-cdn.net/OTP-26.2.1/linux/x86_64/any/otp_26.2.1_linux_any_x86_64_ssl_3.1.4.tar.gz?please-respect-my-bandwidth-costs=thank-you";
          sha256 = "11z50xrmngsn0bzg7vn7w5h76iwmhscx01vij9ir2ivybjc8niky";
        };
        musl = builtins.fetchurl {
          url = "https://beam-machine-universal.b-cdn.net/musl/libc-musl-17613ec13d9aa9e5e907e6750785c5bbed3ad49472ec12281f592e2f0f2d3dbd.so?please-respect-my-bandwidth-costs=thank-you";
          sha256 = "1g9x5l7jybjr3wl15v3jjka3mvdvqn2hfxg60zlybacs7p0kwq8p";
        };
      in
        f {inherit system pkgs beamPackages elixir beam musl;});

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
      beam,
      musl,
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
          mixEnv = "prod";
          inherit version elixir;
          inherit (beamPackages) erlang;

          nativeBuildInputs = [pkgs.xz pkgs.zig_0_11 aliased_7zz beam];

          mixFodDeps = beamPackages.fetchMixDeps {
            src = self.outPath;
            inherit version elixir;
            pname = "next-ls-deps";
            hash = "sha256-JJbiJhVqeRrJseyDyxaUOmTDmSQTfOXuMLEHLhETJek=";
            mixEnv = "prod";
          };

          BURRITO_ERTS_PATH = "/tmp/beam/";
          BURRITO_TARGET = lib.optional localBuild burritoExe.${system};

          preBuild = ''
            export HOME="$TEMPDIR"
            mkdir -p /tmp/beam/otp
            cp -r --no-preserve=mode,ownership,timestamps ${beam}/. /tmp/beam/otp
            cp --no-preserve=ownership,timestamps ${musl} /tmp/libc-musl-17613ec13d9aa9e5e907e6750785c5bbed3ad49472ec12281f592e2f0f2d3dbd.so
            chmod +x /tmp/libc-musl-17613ec13d9aa9e5e907e6750785c5bbed3ad49472ec12281f592e2f0f2d3dbd.so
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
        packages = [pkgs.zsh beamPackages.erlang elixir pkgs.xz pkgs.zig_0_11 pkgs._7zz pkgs.starship pkgs.ncurses5 pkgs.autoconf pkgs.automake pkgs.openssl];
      };
    });
  };
}
