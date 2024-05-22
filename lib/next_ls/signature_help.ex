defmodule NextLS.SignatureHelp do
  @moduledoc false

  alias GenLSP.Enumerations.MarkupKind
  alias GenLSP.Structures.MarkupContent
  alias GenLSP.Structures.ParameterInformation
  alias GenLSP.Structures.SignatureHelp
  alias GenLSP.Structures.SignatureInformation
  alias NextLS.ASTHelpers

  def fetch(text, position) do
    ast =
      text
      |> Spitfire.parse(literal_encoder: &{:ok, {:__literal__, &2, [&1]}})
      |> then(fn
        {:ok, ast} -> ast
        {:error, ast, _} -> ast
      end)

    with {:ok, result} <- ASTHelpers.Function.find_remote_function_call_within(ast, position) do
      case result do
        {:|>, _, [_, {{:., _, [{:__aliases__, _, modules}, name]}, _, _} = node]} ->
          param_index = ASTHelpers.Function.find_params_index(node, position)

          if param_index do
            {:ok, {Module.concat(modules), name, param_index + 1}}
          else
            {:ok, {Module.concat(modules), name, nil}}
          end

        {{:., _, [{:__aliases__, _, modules}, name]}, _, _} = node ->
          param_index = ASTHelpers.Function.find_params_index(node, position)

          {:ok, {Module.concat(modules), name, param_index}}

        _otherwise ->
          {:error, :not_found}
      end
    end
  end

  def format({:ok, {:docs_v1, _, _lang, content_type, _, _, docs}}, func_name, param_index) do
    for {{_, name, _arity}, _, [signature], fdoc, _} <- docs, name == func_name do
      params_info =
        signature
        |> Spitfire.parse!()
        |> Sourceror.get_args()
        |> Enum.map(fn {name, _, _} ->
          %ParameterInformation{
            label: Atom.to_string(name)
          }
        end)

      %SignatureHelp{
        signatures: [
          %SignatureInformation{
            label: signature,
            parameters: params_info,
            documentation: maybe_doc(content_type, fdoc),
            active_parameter: param_index
          }
        ]
      }
    end
  end

  def format({:ok, {:error, :module_not_found}}, _func_name, _param_index) do
    []
  end

  def format({:error, :not_ready}, _func_name, _param_index) do
    []
  end

  defp maybe_doc(content_type, %{"en" => fdoc}) do
    %MarkupContent{
      kind: MarkupKind.markdown(),
      value: NextLS.Docs.to_markdown(content_type, fdoc)
    }
  end

  defp maybe_doc(_content_type, _fdoc), do: nil
end
