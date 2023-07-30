defmodule NextLS.Definition do
  @moduledoc false
  import NextLS.DB.Query

  alias NextLS.DB

  def fetch(file, {line, col}, db) do
    [[_pk, identifier, _arity, _file, type, module, _start_l, _start_c, _end_l, _end_c]] =
      DB.query(
        db,
        ~Q"""
        SELECT
            *
        FROM
            'references' AS refs
        WHERE
            refs.file = ?
            AND refs.start_line <= ?
            AND ? <= refs.end_line
            AND refs.start_column <= ?
            AND ? <= refs.end_column;
        """,
        [file, line, line, col, col]
      )

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

    args =
      case type do
        "alias" ->
          [module, module]

        "function" ->
          [module, identifier]

        _ ->
          nil
      end

    if args do
      DB.query(db, query, args)
    else
      nil
    end
  end
end
