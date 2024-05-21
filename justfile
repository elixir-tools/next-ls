default: deps compile build-local

choose:
  just --choose

deps:
  mix deps.get

compile:
  mix compile

start:
  bin/start --port 9000

test:
  mix test

format:
  mix format

lint: 
  #!/usr/bin/env bash
  set -euxo pipefail

  mix format --check-formatted
  mix credo
  mix dialyzer

[unix]
build-local:
  #!/usr/bin/env bash
  case "{{os()}}-{{arch()}}" in
    "linux-arm" | "linux-aarch64")
      target=linux_arm64;;
    "linux-x86" | "linux-x86_64")
      target=linux_amd64;;
    "macos-arm" | "macos-aarch64")
      target=darwin_arm64;;
    "macos-x86" | "macos-x86_64")
      target=darwin_amd64;;
    *)
      echo "unsupported OS/Arch combination"
      exit 1;;
  esac

  NEXTLS_RELEASE_MODE=burrito BURRITO_TARGET="$target" MIX_ENV=prod mix release

[windows]
build-local:
  # idk actually how to set env vars like this on windows, might crash
  NEXTLS_RELEASE_MODE=burrito BURRITO_TARGET="windows_amd64" MIX_ENV=prod mix release

build-all:
  NEXTLS_RELEASE_MODE=burrito MIX_ENV=prod mix release

build-plain:
  MIX_ENV=prod mix release plain

bump-spitfire:
  mix deps.update spitfire
