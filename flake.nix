{
  # not sure what this is
  inputs.systems.url = "github:nix-systems/default";

  outputs = {
    self,
    nixpkgs,
    systems,
    flake-utils,
    }:
    # not sure how to use this function
    flake-utils.lib.eachSystem (import systems) #what is systems?
    (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Set the Erlang version
        erlangVersion = "erlangR26";
        # Set the Elixir version
        elixirVersion = "elixir_1_15";

        erlang = pkgs.beam.interpreters.${erlangVersion};
        beamPackages = pkgs.beam.packages.${erlangVersion};
        elixir = beamPackages.${elixirVersion};
      in  {
        # this doesn't work for some reason
        packages."<system>".default = with import <nixpkgs> {}; stdenv.mkDerivation {
          name = "next-ls";
          src = self;
          buildInputs = [
            erlang
            elixir
            pkgs.zig
          ];

          buildPhase = ''
            mix local.hex --force
            mix local.rebar --force
            mix deps.get
            BURRITO_TARGET="darwin_arm64" MIX_ENV=prod mix release
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp burrito_out/next_ls_darwin_arm64 $out/bin
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            erlang
            elixir
          ];
        };
      }
    );
}
