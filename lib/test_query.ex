defmodule TestQuery do
  @moduledoc """
  Top-level module used in "Querying RDF with Elixir"

  This module provides test functions for the SPARQL module.
  """

  alias RDF.Turtle

  @data_dir "#{:code.priv_dir(:test_query)}/data/"
  @data_file "978-1-68050-252-7.ttl"

  @query """
  select *
  where {
    ?s ?p ?o
  }
  """

  @doc """
  Reads default RDF model in Turtle format.
  """
  def data do
    Turtle.read_file!(@data_dir <> @data_file)
  end

  @doc """
  Queries default RDF model with default SPARQL query.
  """
  def query do
    query(@query)
  end

  @doc """
  Queries default RDF model with user SPARQL query.
  """
  def query(query) do
    turtle_read  = Turtle.read_file!(@data_dir <> @data_file)
    turtle_read |> SPARQL.execute_query(query)
  end
end
