defmodule NextLS.Parser do
  @moduledoc false
  def parse!(code, opts \\ []) do
    {m, f} =
      if System.get_env("NEXTLS_SPITFIRE_ENABLED", "0") == "1" do
        {Spitfire, :parse!}
      else
        {Code, :string_to_quoted!}
      end

    apply(m, f, [code, opts])
  end

  def parse(code, opts \\ []) do
    {m, f} =
      if System.get_env("NEXTLS_SPITFIRE_ENABLED", "0") == "1" do
        {Spitfire, :parse}
      else
        {Code, :string_to_quoted}
      end

    apply(m, f, [code, opts])
  end
end
