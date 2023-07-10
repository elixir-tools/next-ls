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
- Hover

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
</ul>

## Installation

The preferred way to use NextLS is through one of the supported editor extensions.

If you need to install NextLS on it's own, you can download the executable hosted by the GitHub release. The executable is an Elixir script that utilizes `Mix.install/2`.

### Note

NextLS creates an `.elixir-tools` hidden directory in your project.

This should be added to your project's `.gitignore`.
