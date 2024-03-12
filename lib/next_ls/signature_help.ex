defmodule NextLS.SignatureHelp do
  @moduledoc false

  alias GenLSP.Enumerations.MarkupKind
  alias GenLSP.Structures.MarkupContent
  alias GenLSP.Structures.ParameterInformation
  alias GenLSP.Structures.SignatureHelp
  alias GenLSP.Structures.SignatureInformation
  alias Sourceror.Zipper

  def fetch_mod_and_name(uri, position) do
    with {:ok, text} <- File.read(URI.parse(uri).path),
         ast =
           text
           |> Spitfire.parse()
           |> then(fn
             {:ok, ast} -> ast
             {:error, ast, _} -> ast
           end),
         {:ok, result} <- find_node(ast, position) do
      case result do
        {{:., _, [{:__aliases__, _, modules}, name]}, _, _} -> {:ok, {Module.concat(modules), name}}
      end
    end
  end

  def format({:ok, {:docs_v1, _, :elixir, _, _, _, docs}}, func_name) do
    docs
    |> Enum.filter(fn
      {{_, name, _arity}, _, _, _, _} -> name == func_name
    end)
    |> Enum.map(fn
      {{_, _name, _arity}, _, [signature], _, _} ->
        params_info =
          signature
          |> Spitfire.parse!()
          |> then(fn {_, _, args} ->
            Enum.map(args, fn {name, _, _} -> name end)
          end)
          |> Enum.map(fn name ->
            %ParameterInformation{
              label: Atom.to_string(name)
            }
          end)

        %SignatureHelp{
          signatures: [
            %SignatureInformation{
              label: signature,
              parameters: params_info,
              documentation: %MarkupContent{
                kind: MarkupKind.markdown(),
                value: ""
              }
            }
          ]
        }

      # {{_, _name, _arity}, _, [], _, _} ->
      #   []

      _otherwise ->
        []
    end)
  end

  def format({:ok, {:error, :module_not_found}}, _func_name) do
    []
  end

  defp find_node(ast, {line, column}) do
    position = [line: line, column: column]

    result =
      ast
      |> Zipper.zip()
      |> Zipper.find(fn
        {{:., _, _}, _metadata, _} = node ->
          range = Sourceror.get_range(node)

          Sourceror.compare_positions(range.start, position) == :lt &&
            Sourceror.compare_positions(range.end, position) == :gt

        _ ->
          false
      end)

    if result do
      {:ok, Zipper.node(result)}
    else
      {:error, :not_found}
    end
  end
end
