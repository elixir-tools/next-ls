defmodule NextLS.SnippetTest do
  use ExUnit.Case, async: true

  alias NextLS.Snippet

  describe "defmodule snippet" do
    test "simple module" do
      assert %{insert_text: "defmodule ${1:Foo} do\n  $0\nend\n", insert_text_format: 2, kind: 15} ==
               Snippet.get("defmodule/2", nil, uri: "lib/foo.ex")
    end

    test "nested module" do
      assert %{insert_text: "defmodule ${1:Foo.Bar.Baz} do\n  $0\nend\n", insert_text_format: 2, kind: 15} ==
               Snippet.get("defmodule/2", nil, uri: "lib/foo/bar/baz.ex")
    end

    test "test module" do
      assert %{insert_text: "defmodule ${1:FooTest} do\n  $0\nend\n", insert_text_format: 2, kind: 15} ==
               Snippet.get("defmodule/2", nil, uri: "test/foo_test.exs")
    end

    test "support test module" do
      assert %{insert_text: "defmodule ${1:Foo} do\n  $0\nend\n", insert_text_format: 2, kind: 15} ==
               Snippet.get("defmodule/2", nil, uri: "test/support/foo.ex")
    end

    test "module outside canonical folders" do
      assert %{insert_text: "defmodule ${1:Foo} do\n  $0\nend\n", insert_text_format: 2, kind: 15} ==
               Snippet.get("defmodule/2", nil, uri: "foo.ex")
    end

    test "without uri" do
      assert %{insert_text: "defmodule ${1:ModuleName} do\n  $0\nend\n", insert_text_format: 2, kind: 15} ==
               Snippet.get("defmodule/2", nil)
    end
  end
end
