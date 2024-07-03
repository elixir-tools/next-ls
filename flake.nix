{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zigpkgs = {
      url = "github:NixOS/nixpkgs/592a779f3c5e7bce1a02027abe11b7996816223f";
    };
  };

  nixConfig = {
    extra-substituters = ["https://elixir-tools.cachix.org"];
    extra-trusted-public-keys = ["elixir-tools.cachix.org-1:GfK9E139Ysi+YWeS1oNN9OaTfQjqpLwlBaz+/73tBjU="];
  };

  outputs = {
    self,
    nixpkgs,
    zigpkgs,
  }: let
    inherit (nixpkgs) lib;

    # Helper to provide system-specific attributes
    forAllSystems = f:
      lib.genAttrs systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        zpkgs = zigpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam_minimal.packages.erlang_27.extend (final: prev: {
          elixir = final.elixir_1_17;
          # This will get upstreamed into nix-beam-flakes at some point
          rebar = prev.rebar.overrideAttrs (_old: {doCheck = false;});
          rebar3 = prev.rebar3.overrideAttrs (_old: {doCheck = false;});
        });
        elixir = beamPackages.elixir_1_17;
      in
        f {inherit system pkgs zpkgs beamPackages elixir;});

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
      ...
    }: {
      default = pkgs.callPackage ./package.nix { inherit beamPackages elixir; };
    });

    devShells = forAllSystems ({
      pkgs,
      zpkgs,
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
          zpkgs.zig_0_11
          pkgs.zsh
        ];
      };
    });
  };
}
