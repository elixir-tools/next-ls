defmodule NextLS.Definition do
  @moduledoc false
  import NextLS.DB.Query

  alias NextLS.DB

  def fetch(file, {line, col}, db) do
    rows =
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
            AND ? <= refs.end_column
        ORDER BY 
          (CASE refs.type
             WHEN 'function' THEN 0
             WHEN 'module' THEN 1
             ELSE 2
           END) asc
        LIMIT 1;
        """,
        [file, line, line, col, col]
      )

    reference =
      case rows do
        [[_pk, identifier, _arity, _file, type, module, _start_l, _start_c, _end_l, _end_c | _]] ->
          %{identifier: identifier, type: type, module: module}

        [] ->
          nil
      end

    with %{identifier: identifier, type: type, module: module} <- reference do
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

          "attribute" ->
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
end
