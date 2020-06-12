defmodule Wittgenstein.Client do
  @moduledoc """

  The Wittgenstein Client

  """

  require Logger
  require OpenTelemetry.Tracer
  require OpenTelemetry.Span
  require OpenTelemetry.SpanUtils
  alias OpenTelemetry.Tracer
  alias OpenTelemetry.SpanUtils

  alias Wittgenstein.Model.Fact
  alias Wittgenstein.Model.Entity
  alias Wittgenstein.Store
  alias Wittgenstein.Consolidation
  alias Wittgenstein.Projection
  alias Wittgenstein.Uri

  @spec state(Fact.t()) :: :ok | {:error, term()}
  def state(fact) do
    Tracer.with_span "wittgenstein.client.state" do
      SpanUtils.set_attributes(%{fact: fact |> Fact.to_map()})
      :ok = Store.persist_fact(fact)

      entity_uri = Fact.entity_uri(fact)

      entity =
        case Store.fetch_entity(entity_uri) do
          {:error, :uri_not_found} -> Entity.new(entity_uri)
          {:ok, entity} -> entity
        end

      {:ok, new_entity} = Consolidation.apply_fact(entity, fact)
      :ok = Store.persist_entity(new_entity)
      :ok = Projection.project(entity_uri)
      :ok
    end
  end

  @spec lookup(Uri.t()) :: {:ok, Entity.t()} | {:error, term()}
  def lookup(uri) do
    Store.fetch_entity(uri)
  end

  def lookup!(uri) do
    {:ok, entity} = lookup(uri)
    entity
  end
end
