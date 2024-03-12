defmodule NextLS.SignatureHelp do
  @moduledoc false

  import NextLS.DB.Query

  alias GenLSP.Enumerations.MarkupKind
  alias GenLSP.Structures.MarkupContent
  alias GenLSP.Structures.ParameterInformation
  alias GenLSP.Structures.SignatureHelp
  alias GenLSP.Structures.SignatureInformation
  alias NextLS.ASTHelpers
  alias NextLS.DB

  def fetch(file, {line, col}, db, _logger) do
    code = File.read!(file)

    {mod, func} =
      ASTHelpers.Functions.get_function_name_from_params(code, line, col)

    query =
      ~Q"""
      SELECT
          *
      FROM
          symbols
      WHERE
          symbols.module = ?
          AND symbols.name = ?;
      """

    args = [Enum.map_join(mod, ".", &Atom.to_string/1), Atom.to_string(func)]

    symbol = DB.query(db, query, args)

    result =
      case symbol do
        nil ->
          nil

        [] ->
          nil

        [[_, _mod, file, type, label, params, line, col | _] | _] = _definition ->
          if type in ["def", "defp"] do
            code_params = params |> :erlang.binary_to_term() |> Macro.to_string() |> dbg()

            signature_params =
              params
              |> :erlang.binary_to_term()
              |> Enum.map(fn {name, _, _} ->
                %ParameterInformation{
                  label: Atom.to_string(name)
                }
              end)
              |> dbg()

            %SignatureHelp{
              signatures: [
                %SignatureInformation{
                  label: "#{label}.#{code_params}",
                  documentation: "need help",
                  parameters: signature_params
                  # active_parameter: 0
                }
              ]
              # active_signature: 1,
              # active_parameter: 0
            }
          else
            nil
          end
      end

    result
  end
end
