defmodule Foo do
  Foo.Bar.check()

  defmodule Quix do
    @moduledoc "Fooo"
    require Logger

    def to_list() do
      Foo.Bar.to_list(Map.new())
    end

    def to_map() do
      Foo.Bar.to_map(List.new())
    end
  end

  defmodule Baz do
    def foo() do
      Foo.Bar.asdf()
    end
  end
end
