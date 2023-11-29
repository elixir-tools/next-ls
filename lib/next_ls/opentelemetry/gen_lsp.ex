defmodule NextLS.OpentelemetryGenLSP do
  @moduledoc false
  require Logger

  @tracer_id __MODULE__

  def setup do
    :ok =
      :telemetry.attach_many(
        "gen_lsp-handler",
        [
          [:gen_lsp, :notify, :server, :start],
          [:gen_lsp, :notify, :server, :stop],
          [:gen_lsp, :request, :server, :start],
          [:gen_lsp, :request, :server, :stop],
          [:gen_lsp, :request, :client, :start],
          [:gen_lsp, :request, :client, :stop],
          [:gen_lsp, :notification, :client, :start],
          [:gen_lsp, :notification, :client, :stop],
          [:gen_lsp, :handle_request, :start],
          [:gen_lsp, :handle_request, :stop],
          [:gen_lsp, :handle_notification, :start],
          [:gen_lsp, :handle_notification, :stop],
          [:gen_lsp, :handle_info, :start],
          [:gen_lsp, :handle_info, :stop]
          # [:gen_lsp, :buffer, :outgoing, :start],
          # [:gen_lsp, :buffer, :outgoing, :stop],
          # [:gen_lsp, :buffer, :incoming, :start],
          # [:gen_lsp, :buffer, :incoming, :stop]
        ],
        &__MODULE__.process/4,
        nil
      )
  end

  def process([:gen_lsp, type1, type2, :start], _measurements, metadata, _config) do
    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      :"gen_lsp.#{type1}.#{type2}",
      metadata,
      %{kind: :server, attributes: metadata}
    )
  end

  def process([:gen_lsp, handle, :start], _measurements, metadata, _config) do
    if handle in [:handle_request, :handle_notification] do
      # set attribute for parent span
      OpenTelemetry.Tracer.set_attribute(:method, metadata[:method])
    end

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      :"next_ls.#{handle}",
      metadata,
      %{kind: :server, attributes: metadata}
    )
  end

  def process([:gen_lsp, _, _, :stop], _measurements, metadata, _config) do
    OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, metadata)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, metadata)
  end

  def process([:gen_lsp, _, :stop], _measurements, metadata, _config) do
    OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, metadata)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, metadata)
  end
end
