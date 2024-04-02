defmodule NextLS.DocsHelpers do
  @moduledoc false

  @spec to_markdown(String.t(), String.t() | list()) :: String.t()
  def to_markdown(type, docs)
  def to_markdown("text/markdown", docs), do: docs

  def to_markdown("application/erlang+html" = type, [{:p, _, children} | rest]) do
    String.trim(to_markdown(type, children) <> "\n\n" <> to_markdown(type, rest))
  end

  def to_markdown("application/erlang+html" = type, [{:div, attrs, children} | rest]) do
    prefix =
      if attrs[:class] in ~w<warning note do dont quote> do
        "> "
      else
        ""
      end

    prefix <> to_markdown(type, children) <> "\n\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:a, attrs, children} | rest]) do
    space = if List.last(children) == " ", do: " ", else: ""

    "[#{String.trim(to_markdown(type, children))}](#{attrs[:href]})" <> space <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [doc | rest]) when is_binary(doc) do
    doc <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:pre, _, [{:code, _, children}]} | rest]) do
    "```erlang\n#{to_markdown(type, children)}\n```\n\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:ul, _, lis} | rest]) do
    "#{to_markdown(type, lis)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:li, _, children} | rest]) do
    "* #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:code, _, bins} | rest]) do
    "`#{IO.iodata_to_binary(bins)}`" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:em, _, bins} | rest]) do
    "_#{IO.iodata_to_binary(bins)}_" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:dl, _, lis} | rest]) do
    "#{to_markdown(type, lis)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:dt, _, children} | rest]) do
    "* #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:dd, _, children} | rest]) do
    "#{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html", []) do
    ""
  end
end
