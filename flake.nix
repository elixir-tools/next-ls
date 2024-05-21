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

    version = "0.22.4"; # x-release-please-version

    # Helper to provide system-specific attributes
    forAllSystems = f:
      lib.genAttrs systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam_minimal.packages.erlang_26;
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
        f {inherit system pkgs beamPackages elixir;});

    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
  in {
    packages = forAllSystems ({
      pkgs,
      system,
      beamPackages,
      elixir,
    }: {
      default = lib.makeOverridable ({
        localBuild,
        beamPackages,
        elixir,
      }:
        beamPackages.mixRelease {
          pname = "next-ls";
          src = self.outPath;
          mixEnv = "prod";
          removeCookie = false;
          inherit version elixir;
          inherit (beamPackages) erlang;

          mixFodDeps = beamPackages.fetchMixDeps {
            src = self.outPath;
            inherit version elixir;
            pname = "next-ls-deps";
            hash = "sha256-qdJf3A+k28J2EDtaC8pLE7HgqzKuCjCWmfezx62wyUs=";
            mixEnv = "prod";
          };

          installPhase = ''
            mix release --no-deps-check --path $out plain
            echo "$out/bin/plain eval \"System.no_halt(true); Application.ensure_all_started(:next_ls)\" \"\$@\"" > "$out/bin/nextls"
            chmod +x "$out/bin/nextls"
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
          pkgs.just
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
