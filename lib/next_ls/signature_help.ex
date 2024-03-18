defmodule NextLS.SignatureHelp do
  @moduledoc false

  alias GenLSP.Structures.ParameterInformation
  alias GenLSP.Structures.SignatureHelp
  alias GenLSP.Structures.SignatureInformation
  alias NextLS.Definition

  def fetch(file, {line, col}, db) do
    case Definition.fetch(file, {line, col}, db) do
      nil ->
        nil

      [] ->
        nil

      [[_, _mod, _file, type, label, params, _line, _col | _] | _] = _definition ->
        if type in ["def", "defp"] do
          term_params =
            :erlang.binary_to_term(params)

          code_params =
            term_params
            |> Macro.to_string()
            |> String.replace_prefix("[", "(")
            |> String.replace_suffix("]", ")")

          params_info =
            term_params
            |> Enum.map(&Macro.to_string/1)
            |> Enum.map(fn name ->
              %ParameterInformation{
                label: name
              }
            end)

          %SignatureHelp{
            signatures: [
              %SignatureInformation{
                label: "#{label}#{code_params}",
                parameters: params_info
              }
            ]
          }
        else
          nil
        end
    end
  end
end
