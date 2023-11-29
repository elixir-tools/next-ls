defmodule NextLS.OpentelemetrySchematic do
  @moduledoc false
  require Logger

  @tracer_id __MODULE__

  def setup do
    :ok =
      :telemetry.attach_many(
        "schematic-handler",
        [
          [:schematic, :unify, :start],
          [:schematic, :unify, :stop]
        ],
        &__MODULE__.process/4,
        nil
      )
  end

  def process([:schematic, :unify, :start], _measurements, metadata, _config) do
    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      :"schematic.unify.#{metadata.kind} #{metadata.dir}",
      metadata,
      %{kind: :server, attributes: metadata}
    )
  end

  def process([:schematic, :unify, :stop], _measurements, metadata, _config) do
    OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, metadata)
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, metadata)
  end
end
