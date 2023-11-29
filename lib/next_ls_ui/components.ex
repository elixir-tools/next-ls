defmodule NextLS.UI.Component do
  @moduledoc false
  use Temple.Component

  defmacro __using__(_) do
    quote do
      import Temple
      import unquote(__MODULE__)
    end
  end
end

defmodule NextLS.UI.Components do
  @moduledoc false
  use NextLS.UI.Component

  @env Mix.env()

  def root(assigns) do
    assigns = Map.put(assigns, :env, @env)

    temple do
      "<!DOCTYPE html>"

      html lang: "en" do
        head do
          meta charset: "utf-8"
          meta http_equiv: "X-UA-Compatible", content: "IE=edge"
          meta name: "viewport", content: "width=device-width, initial-scale=1.0"

          title do
            "Next LS Inspector"
          end

          script src: "https://unpkg.com/htmx.org@1.9.6"
          script src: "https://unpkg.com/htmx.org/dist/ext/ws.js"
          script src: "https://unpkg.com/htmx.org/dist/ext/morphdom-swap.js"

          script src: "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.0/chart.umd.min.js"

          script src: "https://cdn.jsdelivr.net/npm/luxon@^2"
          script src: "https://cdn.jsdelivr.net/npm/chartjs-adapter-luxon@^1"


          link rel: "stylesheet", href: "/css/site.css"
        end

        body class: "bg-zinc-200 dark:bg-zinc-900 font-sans", hx_ext: "morphdom-swap" do
          main class: "container mx-auto" do
            header class: "mb-8 py-2" do
              div class: "flex items-center space-x-2" do
                a href: "/", class: "hover:underline" do
                  img src: "/nextls-logo-no-background.png", class: "h-8 w-8"
                end

                h2 class: "text-xl dark:text-white" do
                  a href: "/" do
                    "Next LS Inspector"
                  end
                end
              end
            end

            slot @inner_block

            footer class: "flex justify-between dark:text-white mt-8 py-4" do
              div do
                a class: "underline",
                  href: "https://github.com/elixir-tools/next-ls",
                  do: "Source Code"
              end

              div class: "italic" do
                span do: "Built with"

                a class: "underline",
                  href: "https://github.com/mhanberg/temple",
                  do: "Temple,"

                a class: "underline",
                  href: "https://tailwindcss.com",
                  do: "TailwindCSS,"

                a class: "underline",
                  href: "https://htmx.org",
                  do: "HTMX,"

                " and"

                span class: "text-red-500", do: "♥"
              end
            end
          end

          if @env == :dev do
            c &WebDevUtils.Components.live_reload/1
          end
        end
      end
    end
  end

  def card(assigns) do
    temple do
      div class: "#{assigns[:class]} bg-zinc-50 dark:bg-zinc-700 dark:text-white rounded shadow-xl p-2",
          rest!: Map.take(assigns, [:id]) do
        slot @inner_block
      end
    end
  end
end
