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

  @query_dir "#{:code.priv_dir(:test_query)}/queries/"

  @service "http://dbpedia.org/sparql"

  @doc false
  def get_query, do: @query

  @doc false
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

  @doc """
  Queries default RDF service with saved SPARQL queries.

  This function also stores results in per-query ETS tables.
  """
  def rquery_all do
    all = Path.wildcard(@query_dir <> "*.rq")

    query_files = all |> Enum.map(&Path.basename/1)

    for query_file <- query_files do
      read_query = _read_query(query_file)
      read_query |> _get_data
    end
  end

  @doc """
  Reads RDF data from ETS table and prints it.
  """
  def read_table(table_name) do
    tbl = :ets.tab2list(table_name)
    tbl |> Enum.each(&_read_tuple/1)
  end

  @doc false
  defp _read_query(query_file) do
    IO.puts "Reading #{query_file}"

    query =
      case File.open(@query_dir <> query_file, [:read]) do
        {:ok, file} ->
          IO.read(file, :all)
        {:error, reason} ->
          raise "! Error: #{reason}"
      end
    {query, Module.concat(__MODULE__, Path.basename(query_file, ".rq"))}
  end

  @doc false
  defp _get_data({query, table_name}),
    do: _get_data(query, table_name)

  @doc false
  defp _get_data(query, table_name) do
    IO.puts "Writing #{table_name}"

    :ets.new(table_name, [:named_table])

    case Client.query(query, @service) do
      {:ok, result} ->
        result.results |> Enum.each(
          fn t -> :ets.insert(table_name, _build_spo_tuple(t)) end
        )
      {:error, reason} ->
        raise "! Error: #{reason}"
    end
  end

  @doc false
  defp _build_spo_tuple(t) do
    s = t["s"].value
    p = t["p"].value
    o =
      case t["o"] do
        %RDF.IRI{} -> t["o"].value
        %RDF.Literal{} -> t["o"].value
        %RDF.BlankNode{} -> t["o"].id
        _ -> raise "! Error: Could not get type of object term"
      end
    {System.os_time(), s, p, o, t}
  end

  @doc false
  defp _read_tuple(tuple) do
    {_, _, _, o, _} = tuple
    IO.puts o
  end
end
