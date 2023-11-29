defmodule NextLS.UI.Websocket do
  @moduledoc false
  defmodule Reload do
    @moduledoc false

    def init(_args) do
      :ok = WebDevUtils.LiveReload.init()

      {:ok, %{}}
    end

    def handle_in({"subscribe", [opcode: :text]}, state) do
      {:push, {:text, "subscribed"}, state}
    end

    def handle_info({:reload, _asset_type}, state) do
      {:push, {:text, "reload"}, state}
    end

    def handle_info({:file_event, _watcher_pid, {_path, _event}} = file_event, state) do
      WebDevUtils.LiveReload.reload!(file_event,
        patterns: [
          ~r"lib/next_ls_ui/.*.ex",
          ~r"assets/.*.(css|js)"
        ]
      )

      {:ok, state}
    end
  end

  defmodule Logs do
    @moduledoc false
    import Temple

    require Logger

    def init(_args) do
      Registry.register(NextLS.UI.Registry, :log_socket, true)

      {:ok, %{}}
    end

    def handle_info({:log, event}, state) do
      resp =
        if event.level == :notice do
          ""
        else
          {_formatter, config} = Logger.default_formatter(colors: [enabled: false])

          temple do
            div id: "logs", hx_swap_oob: "beforeend" do
              div data_log_type: event.level,
                  class: """
                  hidden
                  #{log_show(event.level)}
                  data-[log-type=error]:text-red-500
                  data-[log-type=warning]:text-yellow-500
                  data-[log-type=info]:text-white
                  data-[log-type=debug]:text-cyan-500
                  """ do
                Logger.Formatter.format(event, config)
              end
            end
          end
        end

      {:push, {:text, resp}, state}
    end

    def handle_info(message, state) do
      Logger.notice("Unhandled message: #{inspect(message)}")

      {:ok, state}
    end

    defp log_show(type) do
      case type do
        :error -> "group-data-[log-show-error]:block"
        :warning -> "group-data-[log-show-warning]:block"
        :info -> "group-data-[log-show-info]:block"
        :debug -> "group-data-[log-show-debug]:block"
      end
    end
  end

  defmodule Activity do
    @moduledoc false
    import Temple

    require Logger

    def init(_args) do
      Registry.register(NextLS.UI.Registry, :activity_socket, true)
      :timer.send_interval(5000, :update)
      {:ok, %{data: [], last: %{count: 0}}}
    end

    def handle_info({:activity, count, time}, state) do
      {:ok, put_in(state.data, [%{count: count, time: time} | state.data])}
    end

    def handle_info(:update, state) do
      now = DateTime.utc_now() |> DateTime.to_unix(:millisecond) |> to_string()

      assigns =
        if state.data == [] do
          %{
            counts: to_string(state.last.count),
            times: now
          }
        else
          counts = Enum.map_join(state.data, ", ", &"#{&1.count}")
          times = Enum.map_join(state.data, ", ", &"#{&1.time}")

          %{
            counts: counts,
            times: times
          }
        end

      resp =
        temple do
          div id: "activity" do
            script do
              """
              (function() {
                const then = #{now} - 30000;
                chart.data.labels.push(#{@times});
                chart.data.datasets[0].data.push(#{@counts});
                const data = chart.data.datasets[0].data;
                const labels = chart.data.labels.filter((label) => label > then);
                chart.data.labels = labels;
                chart.data.datasets[0].data = data.slice(-labels.length);
                chart.update()
              })();
              """
            end
          end
        end

      {:push, {:text, resp}, %{state | data: [], last: List.first(state.data) || state.last}}
    end

    def handle_info(message, state) do
      Logger.notice("Unhandled message: #{inspect(message)}")

      {:ok, state}
    end

    def javascript_escape(data) when is_binary(data), do: javascript_escape(data, "")

    defp javascript_escape(<<0x2028::utf8, t::binary>>, acc), do: javascript_escape(t, <<acc::binary, "\\u2028">>)

    defp javascript_escape(<<0x2029::utf8, t::binary>>, acc), do: javascript_escape(t, <<acc::binary, "\\u2029">>)

    defp javascript_escape(<<0::utf8, t::binary>>, acc), do: javascript_escape(t, <<acc::binary, "\\u0000">>)

    defp javascript_escape(<<"</", t::binary>>, acc), do: javascript_escape(t, <<acc::binary, ?<, ?\\, ?/>>)

    defp javascript_escape(<<"\r\n", t::binary>>, acc), do: javascript_escape(t, <<acc::binary, ?\\, ?n>>)

    defp javascript_escape(<<h, t::binary>>, acc) when h in [?", ?', ?\\, ?`],
      do: javascript_escape(t, <<acc::binary, ?\\, h>>)

    defp javascript_escape(<<h, t::binary>>, acc) when h in [?\r, ?\n],
      do: javascript_escape(t, <<acc::binary, ?\\, ?n>>)

    defp javascript_escape(<<h, t::binary>>, acc), do: javascript_escape(t, <<acc::binary, h>>)

    defp javascript_escape(<<>>, acc), do: acc
  end
end
