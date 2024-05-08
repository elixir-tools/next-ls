defmodule NextLS.Docs do
  @moduledoc false

  defstruct module: nil, mdoc: nil, functions: [], content_type: nil

  def new({:docs_v1, _, _lang, content_type, mdoc, _, fdocs}, module) do
    mdoc =
      case mdoc do
        %{"en" => mdoc} -> mdoc
        _ -> nil
      end

    %__MODULE__{
      content_type: content_type,
      module: module,
      mdoc: mdoc,
      functions: fdocs
    }
  end

  def new(_, _) do
    nil
  end

  def module(%__MODULE__{} = doc) do
    """
    ## #{Macro.to_string(doc.module)}

    #{to_markdown(doc.content_type, doc.mdoc)}
    """
  end

  def function(%__MODULE__{} = doc, callback) do
    result =
      Enum.find(doc.functions, fn {{type, name, arity}, _some_number, _signature, doc, other} ->
        type in [:function, :macro] and callback.(name, arity, doc, other)
      end)

    case result do
      {{_, name, arity}, _some_number, signature, %{"en" => fdoc}, _other} ->
        """
        ## #{Macro.to_string(doc.module)}.#{name}/#{arity}

        `#{signature}`

        #{to_markdown(doc.content_type, fdoc)}
        """

      _ ->
        nil
    end
  end

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

  def to_markdown("application/erlang+html" = type, [{:h1, _, children} | rest]) do
    "# #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:h2, _, children} | rest]) do
    "## #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:h3, _, children} | rest]) do
    "### #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:h4, _, children} | rest]) do
    "#### #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:h5, _, children} | rest]) do
    "##### #{to_markdown(type, children)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:pre, _, [{:code, _, children}]} | rest]) do
    "```erlang\n#{to_markdown(type, children)}\n```\n\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:ul, [class: "types"], lis} | rest]) do
    "### Types\n\n#{to_markdown(type, lis)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:ul, _, lis} | rest]) do
    "#{to_markdown(type, lis)}\n" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html" = type, [{:li, [name: text], _} | rest]) do
    "* #{text}\n" <> to_markdown(type, rest)
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

  def to_markdown("application/erlang+html" = type, [{:i, _, children} | rest]) do
    "_#{IO.iodata_to_binary(children)}_" <> to_markdown(type, rest)
  end

  def to_markdown("application/erlang+html", []) do
    ""
  end

  def to_markdown("application/erlang+html", nil) do
    ""
  end
end
