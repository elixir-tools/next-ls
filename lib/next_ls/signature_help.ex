defmodule NextLS.SignatureHelp do
  @moduledoc false

  alias GenLSP.Enumerations.MarkupKind
  alias GenLSP.Structures.MarkupContent
  alias GenLSP.Structures.ParameterInformation
  alias GenLSP.Structures.SignatureHelp
  alias GenLSP.Structures.SignatureInformation
  alias NextLS.ASTHelpers

  def fetch_mod_and_name(text, position) do
    ast =
      text
      |> Spitfire.parse(literal_encoder: &{:ok, {:__literal__, &2, [&1]}})
      |> then(fn
        {:ok, ast} -> ast
        {:error, ast, _} -> ast
      end)

    with {:ok, result} <- ASTHelpers.Function.find_remote_function_call_within(ast, position) do
      case result do
        {{:., _, [{:__aliases__, _, modules}, name]}, _, _} -> {:ok, {Module.concat(modules), name}}
      end
    end
  end

  def format({:ok, {:docs_v1, _, _lang, content_type, _, _, docs}}, func_name) do
    for {{_, name, _arity}, _, [signature], fdoc, _} <- docs, name == func_name do
      params_info =
        signature
        |> Spitfire.parse!()
        |> then(fn {_, _, args} ->
          Enum.map(args, fn {name, _, _} ->
            %ParameterInformation{
              label: Atom.to_string(name)
            }
          end)
        end)

      %SignatureHelp{
        signatures: [
          %SignatureInformation{
            label: signature,
            parameters: params_info,
            documentation: maybe_doc(content_type, fdoc)
          }
        ]
      }
    end
  end

  def format({:ok, {:error, :module_not_found}}, _func_name) do
    []
  end

  defp maybe_doc(content_type, %{"en" => fdoc}) do
    %MarkupContent{
      kind: MarkupKind.markdown(),
      value: NextLS.DocsHelpers.to_markdown(content_type, fdoc)
    }
  end

  defp maybe_doc(_content_type, _fdoc), do: nil
end
