{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  nixConfig = {
    extra-substituters = ["https://elixir-tools.cachix.org"];
    extra-trusted-public-keys = ["elixir-tools.cachix.org-1:GfK9E139Ysi+YWeS1oNN9OaTfQjqpLwlBaz+/73tBjU="];
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;

    version = "0.20.2"; # x-release-please-version

    # Helper to provide system-specific attributes
    forAllSystems = f:
      lib.genAttrs (builtins.attrNames burritoExe) (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam_minimal.packages.erlang_26;
        beam = fetchTarball beams.${system};
        rawmusl = musls.${system};
        musl = lib.optionals nixpkgs.legacyPackages.${system}.stdenv.isLinux (builtins.fetchurl (nixpkgs.lib.attrsets.getAttrs ["url" "sha256"] musls.${system}));
        otp = (pkgs.beam.packagesWith beamPackages.erlang).extend (final: prev: {
          elixir_1_17 = prev.elixir_1_16.override {
            rev = "e3b6a91b173f7e836401a6a75c3906c26bd7fd39";
            # You can discover this using Trust On First Use by filling in `lib.fakeHash`
            sha256 = "sha256-RK0aMW7pz7kQtK9XXN1wVCBxKOJKdQD7I/53V8rWD04=";
            version = "1.17.0-dev";
          };

          elixir = final.elixir_1_17;
          # This will get upstreamed into nix-beam-flakes at some point
          rebar = prev.rebar.overrideAttrs (_old: {doCheck = false;});
          rebar3 = prev.rebar3.overrideAttrs (_old: {doCheck = false;});
        });
        elixir = otp.elixir;
      in
        f {inherit system pkgs beamPackages elixir beam rawmusl musl;});

    burritoExe = {
      "aarch64-darwin" = "darwin_arm64";
      "x86_64-darwin" = "darwin_amd64";
      "x86_64-linux" = "linux_amd64";
      "aarch64-linux" = "linux_arm64";
    };

    beams = {
      "aarch64-darwin" = {
        url = "https://beam-machine-universal.b-cdn.net/OTP-26.2.1/macos/universal/otp_26.2.1_macos_universal_ssl_3.1.4.tar.gz?please-respect-my-bandwidth-costs=thank-you";
        sha256 = "0sdadkl80pixj9q3l71zxamh9zgmnmawsc4hpllgvx9r9hl30f40";
      };
      "x86_64-darwin" = {
        url = "https://beam-machine-universal.b-cdn.net/OTP-26.2.1/macos/universal/otp_26.2.1_macos_universal_ssl_3.1.4.tar.gz?please-respect-my-bandwidth-costs=thank-you";
        sha256 = "0sdadkl80pixj9q3l71zxamh9zgmnmawsc4hpllgvx9r9hl30f40";
      };
      "x86_64-linux" = {
        url = "https://beam-machine-universal.b-cdn.net/OTP-26.2.1/linux/x86_64/any/otp_26.2.1_linux_any_x86_64_ssl_3.1.4.tar.gz?please-respect-my-bandwidth-costs=thank-you";
        sha256 = "11z50xrmngsn0bzg7vn7w5h76iwmhscx01vij9ir2ivybjc8niky";
      };
      "aarch64-linux" = {
        url = "https://beam-machine-universal.b-cdn.net/OTP-26.2.1/linux/aarch64/any/otp_26.2.1_linux_any_aarch64_ssl_3.1.4.tar.gz?please-respect-my-bandwidth-costs=thank-you";
        sha256 = "0ich3xkhbb3sb82m7sncg0pr1d3z92klpwrlh8csr8i1qjhg40h5";
      };
    };

    musls = {
      "x86_64-linux" = {
        url = "https://beam-machine-universal.b-cdn.net/musl/libc-musl-17613ec13d9aa9e5e907e6750785c5bbed3ad49472ec12281f592e2f0f2d3dbd.so?please-respect-my-bandwidth-costs=thank-you";
        sha256 = "1g9x5l7jybjr3wl15v3jjka3mvdvqn2hfxg60zlybacs7p0kwq8p";
        file = "libc-musl-17613ec13d9aa9e5e907e6750785c5bbed3ad49472ec12281f592e2f0f2d3dbd.so";
      };
      "aarch64-linux" = {
        url = "https://beam-machine-universal.b-cdn.net/musl/libc-musl-939d11dcd3b174a8dee05047f2ae794c5c43af54720c352fa946cd8b0114627a.so?please-respect-my-bandwidth-costs=thank-you";
        sha256 = "0yk22h0qpka6m4pka33jajpl6p2cg6pg4ishw3gahx5isgf137ck";
        file = "libc-musl-939d11dcd3b174a8dee05047f2ae794c5c43af54720c352fa946cd8b0114627a.so";
      };
    };
  in {
    packages = forAllSystems ({
      pkgs,
      system,
      beamPackages,
      beam,
      musl,
      rawmusl,
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
            hash = "sha256-aGVoJJPK+2phB9HLoIp50Qz0s+3tA9PU+yg8nvOGNRY=";
            mixEnv = "prod";
          };

          BURRITO_ERTS_PATH = "/tmp/beam/";
          BURRITO_TARGET = lib.optional localBuild burritoExe.${system};

          preBuild =
            ''
              export HOME="$TEMPDIR"
              mkdir -p /tmp/beam/otp
              cp -r --no-preserve=ownership,timestamps ${beam}/. /tmp/beam/otp
            ''
            + (
              if (pkgs.stdenv.isLinux)
              then ''
                cp --no-preserve=ownership,timestamps ${musl} /tmp/${rawmusl.file}
                chmod +x /tmp/${rawmusl.file}
              ''
              else ""
            );

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
    }: let
      aliased_7zz = pkgs.symlinkJoin {
        name = "7zz-aliased";
        paths = [pkgs._7zz];
        postBuild = ''
          ln -s ${pkgs._7zz}/bin/7zz $out/bin/7z
        '';
      };
    in {
      default = pkgs.mkShell {
        # The Nix packages provided in the environment
        packages = [
          beamPackages.erlang
          elixir
          aliased_7zz
          pkgs.autoconf
          pkgs.automake
          pkgs.ncurses5
          pkgs.openssl
          pkgs.starship
          pkgs.xz
          pkgs.zig_0_11
          pkgs.zsh
        ];
      };
    });
  };
}
