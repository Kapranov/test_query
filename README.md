# TestQuery

**TODO: Add description**

Using SPARQL.ex to query over RDF datastores with SPARQL. So let's
have a look at that. In there are two separate packages: `SPARQL.ex`
for querying in-memory RDF models, and `SPARQL.Client.ex` for
dispatching queries to remote RDF models. So let's first deal with
local (in-memory) models and then go on to remote models.

## Create a project

First off, let's create a new project `TestQuery` using the usual Mix
build tool invocation:

```bash
mkdir test_query; cd test_query

mix new .
```

We'll then declare a dependency on `SPARQL.Client.ex` in the `mix.exs`
file. (This will bring in the `RDF.ex` and `SPARQL.ex` modules too.)
And we'll also use the `hackney` HTTP client in Erlang as recommended.

```elixir
# mix.exs
defmodule TestQuery.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_query,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: applications(Mix.env)
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10.1", only: :test},
      {:ex_unit_notifier, "~> 0.1.4", only: :test},
      {:hackney, "~> 1.14.3"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:sparql_client, "~> 0.2.1"},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end

  defp applications(:dev), do: applications(:all) ++ [:remix]
  defp applications(_all), do: [:logger]
end
```

```elixir
# config/config.exs
use Mix.Config

if Mix.env == :dev do
  config :tesla, :adapter, Tesla.Adapter.Hackney
  config :mix_test_watch, clear: true
  config :remix, escript: true, silent: true
end

if Mix.env == :test do
  config :ex_unit_notifier,
    notifier: ExUnitNotifier.Notifiers.NotifySend
end

# import_config "#{Mix.env()}.exs"
```

```elixir
# test/test_helper.exs
ExUnit.configure formatters: [ExUnit.CLIFormatter, ExUnitNotifier]
ExUnit.start()
```

Let's also clear out the boilerplate in `lib/test_query.ex` and add in a
`@moduledoc` annotation.

## Query in-memory RDF models

We're going to need some RDF data. To keep things simple we'll take the
RDF description we generated recently in the project `test_vocab` for a
book resource.

```bash
mkdir -p priv/data
touch priv/data/978-1-68050-252-7.ttl
```

```elixir
# priv/data/978-1-68050-252-7.ttl
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<urn:isbn:978-1-68050-252-7> a bibo:Book ;
    dc:creator <https://twitter.com/bgmarx> ;
    dc:creator <https://twitter.com/josevalim> ;
    dc:creator <https://twitter.com/redrapids> ;
    dc:date "2018-03-14"^^xsd:date ;
    dc:format "Paper" ;
    dc:publisher <https://pragprog.com/> ;
    dc:title "Adopting Elixir"@en .

```

For convenience we'll add this file to the project as
`978–1–68050–252–7.ttl` and we'll add to the directory `priv/data` which
we'll need to create.

Now let's check that we can access this file by creating ourselves a
simple `data/0` function which will just read the file.

```elixir
# lib/test_query.ex
defmodule TestQuery do
  @moduledoc """
  Top-level module used in "Querying RDF with Elixir".

  This module provides test functions for the SPARQL module.
  """

  @data_dir "#{:code.priv_dir(:test_query)}/data/"
  @data_file "978-1-68050-252-7.ttl"

  ## Data query to test access to RDF file

  @doc """
  Reads default RDF model in Turtle format.
  """
  def data do
    RDF.Turtle.read_file!(@data_dir <> @data_file)
  end
end
```

The `@data_dir` attribute uses the Erlang function `:code.priv_dir/1`
to locate the `priv/` directory for the current module (named with an
alias as `TestQuery` in Elixir, and which in Erlang is rendered directly
as `:test_query`).

The function simply calls an RDF read convenience function for a
particular serialization (Turtle). It uses the bang (`!`) form which
returns an Elixir term directly or else errors. We also use the string
concatenation operator `<>` to append the filename to the path.

So, we can try this out now with IEx. We'll also import the module so
that functions can be called without any module name qualification
(although for later ease of use we will include this command in the IEx
configuration file `.iex.exs`).

```bash
bash> touch .iex.exs
bash> cat << 'EOF' > .iex.exs
      import TestQuery
      EOF
bash> make all

iex> data
#=> #RDF.Graph{name: nil
        ~I<urn:isbn:978-1-68050-252-7>
            ~I<http://purl.org/dc/elements/1.1/creator>
                ~I<https://twitter.com/bgmarx>
                ~I<https://twitter.com/josevalim>
                ~I<https://twitter.com/redrapids>
            ~I<http://purl.org/dc/elements/1.1/date>
                %RDF.Literal{value: ~D[2018-03-14], datatype: ~I<http://www.w3.org/2001/XMLSchema#date>}
            ~I<http://purl.org/dc/elements/1.1/format>
                ~L"Paper"
            ~I<http://purl.org/dc/elements/1.1/publisher>
              ~I<https://pragprog.com/>
            ~I<http://purl.org/dc/elements/1.1/title>
              ~L"Adopting Elixir"en
            ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>
              ~I<http://purl.org/ontology/bibo/Book>}
```

And if we want a pretty-printed version of that we can pipe the output
to an RDF write convenience function using the pipe operator `|>`. This
function again uses the bang (`!`) form which returns an Elixir term
directly or else errors.

```bash
iex> data |> RDF.Turtle.write_string! |> IO.puts
#=> <urn:isbn:978-1-68050-252-7>
        a <http://purl.org/ontology/bibo/Book> ;
        <http://purl.org/dc/elements/1.1/creator> <https://twitter.com/bgmarx>, <https://twitter.com/josevalim>, <https://twitter.com/redrapids> ;
        <http://purl.org/dc/elements/1.1/date> "2018-03-14"^^<http://www.w3.org/2001/XMLSchema#date> ;
        <http://purl.org/dc/elements/1.1/format> "Paper" ;
        <http://purl.org/dc/elements/1.1/publisher> <https://pragprog.com/> ;
        <http://purl.org/dc/elements/1.1/title> "Adopting Elixir"@en .
    :ok
```

That's cool.

Now we also need a SPARQL query. Let's just create a simple `select`
query which returns all the RDF terms under the variables `?s`, `?p`,
`?o`. And we'll save that query as the attribute `@query`.

```elixir
# lib/test_query.ex
defmodule TestQuery do
  @moduledoc """
  Top-level module used in "Querying RDF with Elixir"

  This module provides test functions for the SPARQL module.
  """

  # ...

  @query """
  select *
  where {
    ?s ?p ?o
  }
  """

  # ...
end
```

Now let's define a simpl `query/0` function which will just pass off to
a `query/1` function using the `@query` attribute.


```elixir
# lib/test_query.ex
defmodule TestQuery do
  @moduledoc """
  Top-level module used in "Querying RDF with Elixir"

  This module provides test functions for the SPARQL module.
  """

  # ...

  ## Simple remote query functions

  @doc """
  Queries default RDF model with default SPARQL query.
  """
  def query do
    query(@query)
  end
end
```

And now we can define a `query/1` function as:

```elixir
# lib/test_query.ex
defmodule TestQuery do
  @moduledoc """
  Top-level module used in "Querying RDF with Elixir"

  This module provides test functions for the SPARQL module.
  """

  # ...

  ## Simple remote query functions

  @doc """
  Queries default RDF model with user SPARQL query.
  """
  def query(query) do
    RDF.Turtle.read_file!(@data_dir <> @data_file)
    |> SPARQL.execute_query(query)
  end
end
```

This will create an RDF model from our file and execute the SPARQL query
`query` over it. The result is a `SPARQL.Query.Result` struct.

```bash
bash> make all

iex> query
#=> %SPARQL.Query.Result{
      results: [
        %{
          "o" => ~I<https://twitter.com/bgmarx>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://twitter.com/josevalim>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://twitter.com/redrapids>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => %RDF.Literal{value: ~D[2018-03-14], datatype: ~I<http://www.w3.org/2001/XMLSchema#date>},
          "p" => ~I<http://purl.org/dc/elements/1.1/date>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~L"Paper",
          "p" => ~I<http://purl.org/dc/elements/1.1/format>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://pragprog.com/>,
          "p" => ~I<http://purl.org/dc/elements/1.1/publisher>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~L"Adopting Elixir"en,
          "p" => ~I<http://purl.org/dc/elements/1.1/title>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<http://purl.org/ontology/bibo/Book>,
          "p" => ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        }
      ],
      variables: ["s", "p", "o"]
    }
```

And we can process this query result using regular Elixir data access:

```bash
iex> result = v()
iex> result |> Enum.each(&(IO.puts &1["o"]))
#=> https://twitter.com/bgmarx
    https://twitter.com/josevalim
    https://twitter.com/redrapids
    2018-03-14
    Paper
    https://pragprog.com/
    Adopting Elixir
    http://purl.org/ontology/bibo/Book

iex> result |> Enum.each(&(IO.puts &1["p"]))
#=> http://purl.org/dc/elements/1.1/creator
    http://purl.org/dc/elements/1.1/creator
    http://purl.org/dc/elements/1.1/creator
    http://purl.org/dc/elements/1.1/date
    http://purl.org/dc/elements/1.1/format
    http://purl.org/dc/elements/1.1/publisher
    http://purl.org/dc/elements/1.1/title
    http://www.w3.org/1999/02/22-rdf-syntax-ns#type

iex> result |> Enum.each(&(IO.puts &1["s"]))
#=> urn:isbn:978-1-68050-252-7
    urn:isbn:978-1-68050-252-7
    urn:isbn:978-1-68050-252-7
    urn:isbn:978-1-68050-252-7
    urn:isbn:978-1-68050-252-7
    urn:isbn:978-1-68050-252-7
    urn:isbn:978-1-68050-252-7
```

Here the `v()` helper in IEx refers to the last result, i.e. the return
from our `query/0` call. We just match this against the variable `result`
for convenience. We can then pull out all the RDF objects (via the
SPARQL query variable `?o`) from the list of maps and print their string
presentations. We use the partial function application
`&(IO.puts &1["o"])` to print out RDF object values.

Note that there is a new (as yet unreleased) `SPARQL.Query.Result.get/2`
function, which would simplify this expression to:

```elixir
SPARQL.Query.Result.get(result, :o)
```

Now just to check on which functions we have created we can use the
`IEx.Helpers.exports/1` function.

```bash
iex> exports TestQuery
#=> data/0      query/0     query/1     query/2
```

### 6 November 2018 by Oleg G.Kapranov

[1]: https://github.com/tonyhammond/examples/tree/master/test_query
[2]: https://medium.com/@tonyhammond/querying-rdf-with-elixir-2378b39d65cc
