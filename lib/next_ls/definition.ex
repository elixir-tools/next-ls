defmodule NextLS.Definition do
  @moduledoc false
  import NextLS.DB.Query

  alias NextLS.DB

  def fetch(file, {line, col}, db) do
    with [[_pk, identifier, _arity, _file, type, module, _start_l, _start_c, _end_l, _end_c | _]] <-
           DB.query(
             db,
             ~Q"""
             SELECT
                 *
             FROM
                 'references' AS refs
             WHERE
                 refs.file = ?
                 AND ? BETWEEN refs.start_line AND refs.end_line
                 AND ? BETWEEN refs.start_column AND refs.end_column
             ORDER BY refs.id asc
             LIMIT 1;
             """,
             [file, line, col]
           ) do
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
    else
      _ ->
        nil
    end
  end
end
