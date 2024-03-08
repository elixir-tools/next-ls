defmodule NextLS.Snippet do
  @moduledoc false

  def get("defmodule/2", nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defmodule ${1:ModuleName} do
        $0
      end
      """
    }
  end

  def get("defstruct/1", nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defstruct [${1:field}: ${2:default}]
      """
    }
  end

  def get("defprotocol/2", nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defprotocol ${1:ProtocolName} do
        def ${2:function_name}(${3:parameter_name})
      end
      """
    }
  end

  def get("defimpl/2", nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defimpl ${1:ProtocolName} do
        def ${2:function_name}(${3:parameter_name}) do
          $0
        end
      end
      """
    }
  end

  def get("defimpl/3", nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defimpl ${1:ProtocolName}, for: ${2:StructName} do
        def ${3:function_name}(${4:parameter_name}) do
          $0
        end
      end
      """
    }
  end

  def get("def/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      def ${1:function_name}(${2:parameter_1}) do
        $0
      end
      """
    }
  end

  def get("defp/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defp ${1:function_name}(${2:parameter_1}) do
        $0
      end
      """
    }
  end

  def get("defmacro/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defmacro ${1:macro_name}(${2:parameter_1}) do
        quote do
          $0
        end
      end
      """
    }
  end

  def get("defmacrop/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      defmacrop ${1:macro_name}(${2:parameter_1}) do
        quote do
          $0
        end
      end
      """
    }
  end

  def get("for/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      for ${2:item} <- ${1:enumerable} do
        $0
      end
      """
    }
  end

  def get("with/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      with ${2:match} <- ${1:argument} do
        $0
      end
      """
    }
  end

  def get("case/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      case ${1:argument} do
        ${2:match} ->
          ${0::ok}

         _ ->
          :error
      end
      """
    }
  end

  def get("cond/" <> _, nil) do
    %{
      kind: GenLSP.Enumerations.CompletionItemKind.snippet(),
      insert_text_format: GenLSP.Enumerations.InsertTextFormat.snippet(),
      insert_text: """
      cond do
        ${1:condition} ->
          ${0::ok}

        true ->
          ${2::error}
      end
      """
    }
  end

  def get(_label, _trigger_character) do
    nil
  end
end
