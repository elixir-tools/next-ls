{
  lib,
  beamPackages,
  elixir,
}:
beamPackages.mixRelease rec {
  pname = "next-ls";
  src = ./.;
  mixEnv = "prod";
  removeCookie = false;
  version = "0.23.3"; # x-release-please-version

  inherit elixir;
  inherit (beamPackages) erlang;

  mixFodDeps = beamPackages.fetchMixDeps {
    inherit src version elixir;
    pname = "next-ls-deps";
    hash = "sha256-TE/hBsbFN6vlE0/VvdJaTxPah5uOdBfC70uhwNYyD4Y=";
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
}
