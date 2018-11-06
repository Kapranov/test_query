defmodule TestQuery.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client
  """

  alias SPARQL.Client

  @hello_world "http://dbpedia.org/resource/Hello_World"

  @query """
  select *
  where {
    bind (<#{@hello_world}> as ?s)
    ?s ?p ?o
    filter (isLiteral(?o) && langMatches(lang(?o), "en"))
  }
  """

  @service "http://dbpedia.org/sparql"

  def get_query, do: @query
  def get_service, do: @service

  @doc """
  Queries default RDF service and prints out "Hello World".
  """
  def hello do
    case Client.query(@query, @service) do
      {:ok, result} ->
        result.results |> Enum.each(&(IO.puts &1["o"]))
      {:error, reason} ->
        raise "! Error: #{reason}"
    end
  end

  @doc """
  Queries default RDF service with default SPARQL query.
  """
  def rquery do
    Client.query(@query, @service)
  end

  @doc """
  Queries default RDF service with user SPARQL query.
  """
  def rquery(query) do
    Client.query(query, @service)
  end

  @doc """
  Queries a user RDF service with a user SPARQL query.
  """
  def rquery(query, service) do
    Client.query(query, service)
  end
end
