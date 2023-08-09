# Next LS

[![Discord](https://img.shields.io/badge/Discord-5865F3?style=flat&logo=discord&logoColor=white&link=https://discord.gg/nNDMwTJ8)](https://discord.gg/6XdGnxVA2A)
[![Hex.pm](https://img.shields.io/hexpm/v/next_ls)](https://hex.pm/packages/next_ls)
[![GitHub Discussions](https://img.shields.io/github/discussions/elixir-tools/discussions)](https://github.com/orgs/elixir-tools/discussions)

The language server for Elixir that just works. 😎

Still in heavy development, currently supporting the following features:

- Compiler Diagnostics
- Code Formatting
- Workspace Symbols
- Document Symbols
- Go To Definition
- Workspace Folders
- Find References

## Editor Support

<ul>
<li>Neovim: <a href="https://github.com/elixir-tools/elixir-tools.nvim">elixir-tools.nvim</a></li>
<li>VSCode: <a href="https://github.com/elixir-tools/elixir-tools.vscode">elixir-tools.vscode</a></li>
<li>
<details>
<summary>Emacs</summary>

Using eglot:

```elisp
(require 'eglot)

(add-to-list 'exec-path "path/to/next-ls/bin/")

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `((elixir-ts-mode heex-ts-mode elixir-mode) .
                 ("nextls" "--stdio=true"))))

(add-hook 'elixir-mode-hook 'eglot-ensure)
(add-hook 'elixir-ts-mode-hook 'eglot-ensure)
(add-hook 'heex-ts-mode-hook 'eglot-ensure)
```

</details>
</li>
<li>
<details>
<summary>Helix</summary>

Add the following config to your `~/.config/helix/languages.toml`.

```toml
[[language]]
name = "elixir"
scope = "source.elixir"
language-server = { command = "path/to/next-ls", args = ["--stdio=true"] }
```
</details>
</li>
</ul>

## Installation

The preferred way to use Next LS is through one of the supported editor extensions.

If you need to install Next LS on it's own, you can download the executable hosted by the GitHub release. The executable is an Elixir script that utilizes `Mix.install/2`.

## Development

If you are making changes to NextLS and want to test them locally you can run
`bin/start --port 9000` to start the language server (port 9000 is just an
example, you can use any port that you want as long as it is not being used
already).

Then you can configure your editor to connect to NextLS using that port.

[elixir-tools.nvim](https://github.com/elixir-tools/elixir-tools.nvim)

```lua
{
  nextls = {enable = true, port = 9000}
}

Visual Studio Code

```json
{
    "elixir-tools.nextls.adapter": "tcp",
    "elixir-tools.nextls.port": 9000,
}

### Note

Next LS creates an `.elixir-tools` hidden directory in your project, but it will be automatically ignored by `git`.
