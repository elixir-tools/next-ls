defmodule NextLS.DB.Format do
  @moduledoc false
  @behaviour Mix.Tasks.Format

  @impl Mix.Tasks.Format
  def features(_opts), do: [sigils: [:Q], extensions: []]

  @impl Mix.Tasks.Format
  def format(input, _formatter_opts, _opts \\ []) do
    path = Path.join(System.tmp_dir!(), "#{System.unique_integer()}-temp.sql")
    File.write!(path, input)
    {result, 0} = System.cmd("pg_format", [path])

    File.rm!(path)

    String.trim(result) <> "\n"
  end
end
