defmodule NextLS.UI.HomePage do
  @moduledoc false

  use NextLS.UI.Component

  import NextLS.UI.Components

  def run(_conn, assigns) do
    assigns = Map.put(assigns, :node, assigns.query["node"] || Atom.to_string(Node.self()))

    temple do
      c &root/1 do
        div class: "grid grid-cols-1 lg:grid-cols-2 gap-4" do
          c &card/1 do
            h2 class: "text-xl dark:text-white mb-2" do
              "System Information"
            end

            ul do
              li do
                span class: "flex items-center gap-2" do
                  "Version:"
                  pre do: NextLS.version()
                end
              end

              li do
                span class: "flex items-center gap-2" do
                  "Elixir: "
                  pre do: System.version()
                end
              end

              li do
                span class: "flex items-center gap-2" do
                  "OTP:"
                  pre class: "whitespace-pre-wrap", do: :erlang.system_info(:system_version)
                end
              end

              li do
                span class: "flex items-center gap-2" do
                  "OS:"
                  pre class: "whitespace-pre-wrap", do: inspect(:os.type())
                end
              end

              li do
                span class: "flex items-center gap-2" do
                  "Arch:"

                  pre class: "whitespace-pre-wrap",
                      do: :system_architecture |> :erlang.system_info() |> List.to_string()
                end
              end

              li do
                span class: "flex items-center gap-2" do
                  "Schedulers:"

                  pre class: "whitespace-pre-wrap",
                      do: System.schedulers_online()
                end
              end
            end
          end

          c &card/1, class: "col-span-1" do
            div class: "flex flex-col justify-between mb-2" do
              h2 class: "text-lg dark:text-white mb-2" do
                "Node Information"
              end

              select class: "bg-zinc-500 text-zinc-50 dark:bg-zinc-100 dark:text-zinc-950 rounded p-1",
                     name: "node",
                     hx_get: "/node",
                     hx_target: "#node" do
                for n <- [Node.self() | Node.list()] do
                  option value: n, selected: @node == n do
                    n
                  end
                end
              end
            end

            div id: "node" do
              c &node_information/1, node: @node
            end
          end

          c &card/1, class: "col-span-2" do
            h2 class: "text-lg dark:text-white mb-2" do
              "DB Query Lag"
            end

            div class: "w-full" do
              canvas id: "lag"
            end

            div hx_ext: "ws", ws_connect: "/ws/activity" do
              div id: "activity" do
                script do: """
                       var chart = new Chart(
                         document.getElementById('lag'),
                         {
                           type: 'bar',
                           options: {
                             scales: {
                               x: {
                                 type: "time"
                               }
                             }
                           },
                           data: {
                             labels: [],
                             datasets: [
                               {
                                 label: 'DB lag over time',
                                 data: []
                               }
                             ]
                           }
                         }
                       );
                       """
              end
            end
          end

          c &card/1, class: "col-span-1 lg:col-span-2" do
            h2 class: "text-xl dark:text-white mb-2" do
              "Logs"
            end

            div class: "group min-h-[16rem]",
                id: "log-container",
                hx_ext: "ws",
                ws_connect: "/ws/logs",
                data_log_show_error: true,
                data_log_show_warning: true,
                data_log_show_info: true,
                data_log_show_debug: true,
                hx_on:
                  "htmx:wsAfterMessage: event.currentTarget.children.logs.scrollTo(0, event.currentTarget.children.logs.scrollHeight)" do
              div class: "flex gap-4 mb-4" do
                c &log_toggle_button/1, type: :debug do
                  "debug"
                end

                c &log_toggle_button/1, type: :info do
                  "info"
                end

                c &log_toggle_button/1, type: :warning do
                  "warning"
                end

                c &log_toggle_button/1, type: :error do
                  "error"
                end
              end

              div id: "logs", class: "group max-h-72 overflow-y-scroll font-mono" do
                div class: "hidden only:block italic text-sm" do
                  "Nothing yet..."
                end
              end
            end
          end
        end
      end
    end
  end

  def log_toggle_button(assigns) do
    classes =
      case assigns.type do
        :error ->
          "border-red-500 group-data-[log-show-error]:bg-red-500 text-red-500 group-data-[log-show-error]:text-red-950"

        :warning ->
          "border-yellow-500 group-data-[log-show-warning]:bg-yellow-500 text-yellow-500 group-data-[log-show-warning]:text-yellow-950"

        :info ->
          "border-white group-data-[log-show-info]:bg-white text-white group-data-[log-show-info]:text-black"

        :debug ->
          "border-cyan-500 group-data-[log-show-debug]:bg-cyan-500 text-cyan-500 group-data-[log-show-debug]:text-cyan-950"
      end

    assigns = Map.put(assigns, :classes, classes)

    temple do
      button class: "w-16 text-sm rounded border bg-transparent #{@classes}",
             "hx_on:click": "htmx.find('#log-container').toggleAttribute('data-log-show-#{@type}')",
             type: "button" do
        slot @inner_block
      end
    end
  end

  def node_information(assigns) do
    temple do
      ul do
        li do
          span class: "flex items-center gap-2" do
            "Elixir: "
            pre do: :erpc.call(String.to_atom(@node), System, :version, [])
          end
        end

        li do
          span class: "flex items-center gap-2" do
            "OTP:"

            pre class: "whitespace-pre-wrap",
                do: :erpc.call(String.to_atom(@node), :erlang, :system_info, [:system_version])
          end
        end

        li do
          span class: "flex items-center gap-2" do
            "Directory:"

            pre class: "whitespace-pre-wrap",
                do: :erpc.call(String.to_atom(@node), File, :cwd!, [])
          end
        end

        li do
          span class: "flex items-center gap-2" do
            "Elixir exe:"

            pre class: "whitespace-pre-wrap",
                do: :erpc.call(String.to_atom(@node), System, :find_executable, ["elixir"])
          end
        end

        li do
          span class: "flex items-center gap-2" do
            "Erlang exe:"

            pre class: "whitespace-pre-wrap",
                do: :erpc.call(String.to_atom(@node), System, :find_executable, ["erl"])
          end
        end

        li do
          span class: "flex items-center gap-2" do
            "epmd exe:"

            pre class: "whitespace-pre-wrap",
                do: :erpc.call(String.to_atom(@node), System, :find_executable, ["epmd"])
          end
        end

        li do
          span class: "flex items-center gap-2" do
            "Schedulers:"

            pre class: "whitespace-pre-wrap",
                do: :erpc.call(String.to_atom(@node), System, :schedulers_online, [])
          end
        end
      end
    end
  end
end
