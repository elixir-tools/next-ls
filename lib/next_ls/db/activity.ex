defmodule NextLS.DB.Activity do
  @moduledoc false
  @behaviour :gen_statem

  def child_spec(opts) do
    %{
      id: opts[:name] || opts[:id],
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(args) do
    :gen_statem.start_link({:local, Keyword.get(args, :name)}, __MODULE__, Keyword.drop(args, [:name]), [])
  end

  def update(statem, count), do: :gen_statem.cast(statem, count)

  @impl :gen_statem
  def callback_mode, do: :state_functions

  @impl :gen_statem
  def init(args) do
    logger = Keyword.fetch!(args, :logger)
    lsp = Keyword.fetch!(args, :lsp)

    {:ok, :waiting, %{count: 0, logger: logger, lsp: lsp, token: nil}}
  end

  def active(:cast, 0, data) do
    {:keep_state, %{data | count: 0}, [{:state_timeout, 100, :waiting}]}
  end

  def active(:cast, mailbox_count, %{count: 0} = data) do
    {:keep_state, %{data | count: mailbox_count}, [{:state_timeout, :cancel}]}
  end

  def active(:cast, mailbox_count, data) do
    {:keep_state, %{data | count: mailbox_count}, []}
  end

  def active(:state_timeout, :waiting, data) do
    NextLS.Progress.stop(data.lsp, data.token, "Finished indexing!")
    {:next_state, :waiting, %{data | token: nil}}
  end

  def waiting(:cast, 0, _data) do
    :keep_state_and_data
  end

  def waiting(:cast, mailbox_count, data) do
    token = NextLS.Progress.token()
    NextLS.Progress.start(data.lsp, token, "Indexing!")
    {:next_state, :active, %{data | count: mailbox_count, token: token}}
  end
end
