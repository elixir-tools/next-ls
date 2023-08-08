defmodule NextLS.DB.Schema do
  @moduledoc false
  import NextLS.DB.Query

  alias NextLS.DB

  def init(conn) do
    DB.__query__(
      conn,
      ~Q"""
      CREATE TABLE IF NOT EXISTS symbols (
          id integer PRIMARY KEY,
          module text NOT NULL,
          file text NOT NULL,
          type text NOT NULL,
          name text NOT NULL,
          line integer NOT NULL,
          column integer NOT NULL
      );
      """,
      []
    )

    DB.__query__(
      conn,
      ~Q"""
      CREATE TABLE IF NOT EXISTS 'references' (
          id integer PRIMARY KEY,
          identifier text NOT NULL,
          arity integer,
          file text NOT NULL,
          type text NOT NULL,
          module text NOT NULL,
          start_line integer NOT NULL,
          start_column integer NOT NULL,
          end_line integer NOT NULL,
          end_column integer NOT NULL)
      """,
      []
    )
  end
end
