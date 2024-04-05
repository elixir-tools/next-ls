# Next LS

[![Documentation](https://img.shields.io/badge/Next_LS-Documentation-gold)](https://www.elixir-tools.dev/docs/next-ls/quickstart)
[![GitHub release (latest by SemVer including pre-releases)](https://img.shields.io/github/downloads-pre/elixir-tools/next-ls/latest/total?label=Downloads%20-%20Latest%20Release)](https://github.com/elixir-tools/next-ls/releases)
[![GitHub all releases](https://img.shields.io/github/downloads/elixir-tools/next-ls/total?label=Downloads%20(Total))](https://github.com/elixir-tools/next-ls/releases)
[![GitHub Discussions](https://img.shields.io/github/discussions/elixir-tools/discussions)](https://github.com/orgs/elixir-tools/discussions)
[![Discord](https://img.shields.io/badge/Discord-5865F3?style=flat&logo=discord&logoColor=white&link=https://discord.gg/nNDMwTJ8)](https://discord.gg/6XdGnxVA2A)

The language server for Elixir that just works. 😎

Still in heavy development, but early adopters are encouraged!

Please see the [docs](https://www.elixir-tools.dev/docs/next-ls/quickstart) to get started.

## Related Links

- [Introducing Next LS and an elixir-tools update](https://www.elixir-tools.dev/news/introducing-next-ls-and-an-elixir-tools-update/)
- [The elixir-tools Update Vol. 2](https://www.elixir-tools.dev/news/the-elixir-tools-update-vol-2/)
- [The elixir-tools Update Vol. 3](https://www.elixir-tools.dev/news/the-elixir-tools-update-vol-3/)
- [The elixir-tools Update Vol. 4](https://www.elixir-tools.dev/news/the-elixir-tools-update-vol-4/)
- [The 2023 elixir-tools Update (Vol. 5) ](https://www.elixir-tools.dev/news/the-2023-elixir-tools-update-vol-5/)

## Sponsors

Next LS and elixir-tools is sponsored by a ton of amazing people and companies. I urge you to sponsor if you'd like to see the projects reach their maximum potential 🚀.

https://github.com/sponsors/mhanberg

### Platinum + Gold Tier

<!-- gold --><!-- gold -->

### Remaining tiers

<!-- rest --><!-- rest -->

## Development

```bash
# install deps
mix deps.get

# start the local server for development in TCP mode
# see editor extension docs for information on how to connect to a server in TCP mode
bin/start --port 9000

# run the tests
mix test
```

## Production release

Executables are output to `./burrito_out`.

```bash
# produces executables for all the targets specified in the `mix.exs` file
MIX_ENV=prod mix release

# produce an executable for a single target
BURRITO_TARGET=linux_amd64 MIX_ENV=prod mix release
```

## Contributing

This project follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) and will "Squash and Merge" pull requests. 

This means that you don't necessarily need to write your actual commit messages with Conventional Commits, but the Pull Request title needs to, as it is used as the commit title when squashing and merging. There is a CI check to enforce this.

Conventional Commits are required to use [Release Please](https://github.com/googleapis/release-please), which is used to automate the changelog, release, and building/publishing executables.
