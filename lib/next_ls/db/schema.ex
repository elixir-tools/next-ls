defmodule NextLS.DB.Schema do
  @moduledoc """
  The Sqlite3 database schema.

  First, you are probably asking yourself, why doesn't this use Ecto?

  Well, because I didn't want to. And also because I am attempting to restrict this
  project to as few dependencies as possible.

  The Ecto migration system is meant for highly durable data, that can't and shouldn't be lost,
  whereas the data here is more like a fast and efficient cache.

  Rather than coming up with convoluted data migration strategies, we follow the following algorithm.

  1. Create the `schema` table if needed. This includes a version column.
  2. If the max version selected from the `schema` table is equal to the current version, we noop and halt.
     Else, if the max version is less than the current one (compiled into this module) or nil
     we "upgrade" the database.
  3. Unless halting, we drop the non-meta tables, and then create them from scratch
  4. Return a value to signal to the caller that re-indexing is necessary.
  """
  import NextLS.DB.Query

  alias NextLS.DB

  @version 5

  def init(conn) do
    # FIXME: this is odd tech debt. not a big deal but is confusing
    {_, logger} = conn

    NextLS.Logger.log(logger, "Beginning DB migration...")

    DB.__query__(
      conn,
      ~Q"""
      CREATE TABLE IF NOT EXISTS schema (
          id integer PRIMARY KEY,
          version integer NOT NULL DEFAULT 1,
          inserted_at text NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
      """,
      []
    )

    DB.__query__(
      conn,
      ~Q"""
      PRAGMA synchronous = OFF
      """,
      []
    )

    result =
      case DB.__query__(conn, ~Q"SELECT MAX(version) FROM schema;", []) do
        [[version]] when version == @version ->
          NextLS.Logger.info(logger, "Database is on the latest version: #{@version}")
          {:ok, :noop}

        result ->
          version = with([[version]] <- result, do: version) || 0

          NextLS.Logger.info(logger, """
          Database is being upgraded from version #{version} to #{@version}.

          This will trigger a full recompilation in order to re-index your codebase.
          """)

          DB.__query__(conn, ~Q"INSERT INTO schema (version) VALUES (?);", [@version])

          DB.__query__(conn, ~Q"DROP TABLE IF EXISTS symbols;", [])
          DB.__query__(conn, ~Q"DROP TABLE IF EXISTS 'references';", [])

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
                column integer NOT NULL,
                source text NOT NULL DEFAULT 'user',
                inserted_at text NOT NULL DEFAULT CURRENT_TIMESTAMP
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
                end_column integer NOT NULL,
                source text NOT NULL DEFAULT 'user',
                inserted_at text NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """,
            []
          )

          {:ok, :reindex}
      end

    NextLS.Logger.log(logger, "Finished DB migration...")
    result
  end
end
