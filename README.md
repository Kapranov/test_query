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

## Query remote RDF models

To query a remote RDF datastore let's set up a new `TestQuery.Client`
module for our testing with `SPARQL.Client`. We'll add a new directory
`lib/test_query/` and create a `client.ex` file for the module.

```bash
bash> mkdir -p lib/test_query
bash> touch lib/test_query/client.ex
bash> cat << 'EOF' > lib/test_query/client.ex
defmodule TestQuery.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client
  """

end
EOF
```
We're going to be using DBpedia and the DBpedia SPARQL endpoint for our
remote querying.  Let's define some module attributes to make things
easier.

```elixir
# lib/test_query/client.ex
defmodule TestQuery.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client module.
  """

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
end
```

Where's here?

* `@hello_word` - a test URI, here a DBpedia resource
* `@query` - a test SPARQL query using the test URI and matching
             English-language strings for RDF object literal values
* `@service` - a test SPARQL endpoint, here the DBpedia endpoint

Module attributes are private to the module but we can define a couple
of accessor functions:

```elixir
## Accessors for module attributes

def get_query, do: @query
def get_service, do: @service
```

Let's define a `hello/0` function which will use the
`SPARQL.Client.query/2` function to query the test service
(`@service`) with the test query (`@query`).

```elixir
def hello do
  case SPARQL.Client.query(@query, @service) do
    {:ok, result} ->
      result.results |> Enum.each(&(IO.puts &1["o"]))
    {:error, reason} ->
      raise "! Error: #{reason}"
  end
end
```

As before the query result is a `SPARQL.Query.Result` struct, or more
precisely a tuple with an `:ok` atom and the struct which we'll save
to the variable `result`. We can access the actual results (a list of
maps) from the `results` field of the `result` struct and we can pipe
those into `Enum.each/2`, an Elixir enumerable function. Again we use
the partial function application `&(IO.puts &1["o"])` to print out RDF
object values.

```elixir
# .iex.exs
import TestQuery
import TestQuery.Client
```

```elixir
# lib/test_query/client.ex
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
end
```

So, let's try it

```bash
bash> make all
iex> hello
#=> Hello World
```

Great. We just queried DBpedia and parsed the result set for English
language strings.

So we can now define some functions for remote query (`rquery/0`,
`rquery/1`, `rquery/2`) which mirror the local query forms (`query/0`,
`query/1`, `query/2`) we produced earlier.

```elixir
def rquery do
  SPARQL.Client.query(@query, @service)
end

def rquery(query) do
  SPARQL.Client.query(query, @service)
end

def rquery(query, service) do
  SPARQL.Client.query(query, service)
end
```

And again let's check on the functions we have now created with the
`IEx.Helpers.exports/1` function.

```bash
exports TestQuery.Client
#=> get_query/0       get_service/0     hello/0           rquery/0
    rquery/1          rquery/2
```

```elixir
# lib/test_query/client.ex
defmodule TestQuery.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client
  """

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

  ## Accessors for module attributes

  def get_query, do: @query
  def get_service, do: @service

  @doc """
  Queries default RDF service and prints out "Hello World".
  """
  def hello do
    case SPARQL.Client.query(@query, @service) do
      {:ok, result} ->
        result.results |> Enum.each(&(IO.puts &1["o"]))
      {:error, reason} ->
        raise "! Error: #{reason}"
    end
  end

  ## Simple remote query functions

  @doc """
  Queries default RDF service with default SPARQL query.
  """
  def rquery do
    SPARQL.Client.query(@query, @service)
  end

  @doc """
  Queries default RDF service with user SPARQL query.
  """
  def rquery(query) do
    SPARQL.Client.query(query, @service)
  end

  @doc """
  Queries a user RDF service with a user SPARQL query.
  """
  def rquery(query, service) do
    SPARQL.Client.query(query, service)
  end
end
```
Now we're ready to experiment with those functions or move on to
something else.

## Inspect result sets using the Observer

So, at this point let's try something a little more ambitious.

We're going to read a bunch of queries from local file storage, apply
them against a remote service, and store the results for inspection
using one of the really cool Erlang tools that ships with Elixir – the
Observer.

For the queries we'll use one more module attribute `@query_dir` which
uses the Erlang function `:code.priv_dir/1` to locate the `priv/queries/`
directory in the main module.

```bash
bash> mkdir -p priv/queries
```

```elixir
# lib/test_query/client.ex
defmodule TestQuery.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client module.
  """

  # ...

  @query_dir "#{:code.priv_dir(:test_query)}/queries/"

  @service "http://dbpedia.org/sparql"

  # ...
end
```

For this application we'll just save some simple queries to be applied
to a given service. We'll be querying DBpedia again.

The queries are all the same. They are all simple SPARQL select queries,
each querying for a particular hurricane in the 2018 Atlantic hurricane
season.

```elixir
select *
where {
  bind (<http://dbpedia.org/resource/Hurricane_Alberto> as ?s)
  ?s ?p ?o
}
```

So we have this directory structure.

```bash
bash> tree priv/queries/

priv/queries/
├── alberto.rq
├── beryl.rq
├── chris.rq
├── debby.rq
├── ernesto.rq
├── florence.rq
├── gordon.rq
└── helene.rq

0 directories, 8 files
```
Before we get to the Observer, let's talk about the storage for query
results. Be warned that we are going to use an advanced facility of the
Erlang runtime.

Erlang uses the actor model and implements actors as processes which are
one of its main language constructs. These are very lightweight
structures and are implemented at the language level – not the OS level.
Communication between processes is strictly via message passing and
state is private to the process.

Now, Erlang also maintains a powerful storage engine built into the
runtime. This is known as Erlang Term Storage (ETS) and is a robust
in-memory store for Elixir and Erlang terms. Tables in ETS are created
and owned by individual processes. When an owner process terminates, its
tables are destroyed.

There are many reasons to be wary of reaching for ETS tables for
production applications (shared access, garbage collection, etc.) but
for this we will use ETS tables as a simple cache mechanism to store
our query results so that we can inspect these readily with the Observer
tool. Note that normally one would use special process types such as a
GenServer (or an Agent, which is basically a GenServer under the hood)
to hold process private state. But before talking more about the
Observer let's look first at how we will run our queries and save the
results sets to ETS tables.

We'll define a `rquery_all/0` function which will first read filenames
from our query directory and then iterate over those, reading the query
from the file and sending this to the service and storing the results.
We use the `Path.wildcard/1` and `Path.basename/1` file system functions
together with the module attribute which supplies the `/priv/queries/`
directory. The second part uses a list comprehension to iterate over the
`query_files` list. Note that the processing is handled by private
functions which we explicitly label with a leading underscore.

```elixir
# lib/test_query/client.ex
def rquery_all do
  # get list of query files
  query_files =
    Path.wildcard(@query_dir <> "*.rq") |> Enum.map(&Path.basename/1)

  # iterate over query files and process
  for query_file <- query_files,
    do: _read_query(query_file) |> _get_data
end
```

The `_read_query/1` function is defined using `defp` for a private
function. Our plan here is just to slurp the file contents into a
variable `query` and to return this in a tuple together with an ETS
table name. Here the table name is an atom holding a name compounded of
the file name (without file extension) and with the current module as a
prefix. So, for example, the file `alberto.rq` will be used to generate
an ETS table name of `Elixir.TestQuery.Client.alberto`. (Note that the
prefix `Elixir.` is implicit in all Elixir module names.)

```elixir
# lib/test_query/client.ex
defp _read_query(query_file) do
  # output a progress update
  IO.puts "Reading #{query_file}"

  # read query from query_file
  query =
    case File.open(@query_dir <> query_file, [:read]) do
      {:ok, file} ->
        IO.read(file, :all)
      {:error, reason} ->
        raise "! Error: #{reason}"
    end
  {query, Module.concat(__MODULE__, Path.basename(query_file, ".rq"))}
end
```

The function return is piped into a helper function `_get_data/1` which
just unpacks the tuple into two arguments and invokes the real
`_get_data/2` function.


```elixir
# lib/test_query/client.ex
defp _get_data({query, table_name}),
  do: _get_data(query, table_name)

defp _get_data(query, table_name) do
  # output a progress update
  IO.puts "Writing #{table_name}"

  # create ETS table
  :ets.new(table_name, [:named_table])

  # now call SPARQL endpoint and populate ETS table
  case SPARQL.Client.query(query, @service) do
    {:ok, result} ->
      result.results |> Enum.each(
        fn t -> :ets.insert(table_name, _build_spo_tuple(t)) end
      )
    {:error, reason} ->
      raise "! Error: #{reason}"
  end
end
```

This function uses two Erlang functions `:ets.new/2` and `:ets.insert/2`
to create and populate the ETS table. Each result is read from the list
of maps in the `results.result` field of the `SPARQL.Query.Result`
struct and each map is repackaged as a tuple by the `_build_spo_tuple/1`
function.

```elixir
# lib/test_query/client.ex
defp _build_spo_tuple(t) do
  s = t["s"].value
  p = t["p"].value
  # need to test type of object term
  o =
    case t["o"] do
      %RDF.IRI{} -> t["o"].value
      %RDF.Literal{} -> t["o"].value
      %RDF.BlankNode{} -> t["o"].id
      _ -> raise "! Error: Could not get type of object term"
    end
  {System.os_time(), s, p, o, t}
end
```

This function just expects three keys in the triple map `t`: `"s"`, `"p"`, and
`"o"`. Both RDF subjects and predicates are IRIs so we can just fish out
the `value` field of the IRI struct. But RDF objects may be either IRIs,
literals, or blank nodes. So we'll need to test those and use the `value` or
`id` field of  the appropriate struct accordingly.

Note that this testing on RDF object type is admittedly a little
low-level and we might expect a convenience function to support this in
a future release.

We return a tuple for inserting into the ETS table using `:ets.insert/2`
which will list subject `s`, predicate `p`, object `o`, as well as the
raw triple map `t` that was returned. We want to include a key for each
tuple so simply make use of the `System.os_time/0` function to provide a
unique integer ID.

And that's it!

So, let's try it.

```bash
bash> make all

iex> rquery_all
#=> Reading alberto.rq
    Writing Elixir.TestQuery.Client.alberto
    Reading beryl.rq
    Writing Elixir.TestQuery.Client.beryl
    Reading chris.rq
    Writing Elixir.TestQuery.Client.chris
    Reading debby.rq
    Writing Elixir.TestQuery.Client.debby
    Reading ernesto.rq
    Writing Elixir.TestQuery.Client.ernesto
    Reading florence.rq
    Writing Elixir.TestQuery.Client.florence
    Reading gordon.rq
    Writing Elixir.TestQuery.Client.gordon
    Reading helene.rq
    Writing Elixir.TestQuery.Client.helene
    [:ok, :ok, :ok, :ok, :ok, :ok, :ok, :ok]
```

So, something happened. Let's see. For this we'll reach for the
Observer. The Observer is a graphical tool for observing the
characteristics of Erlang systems. The Observer displays system
information, application supervisor trees, process information, ETS
tables, Mnesia tables and contains a front end for Erlang tracing. Just
a lot of things.

We invoke the Observer as: `:observer.start`

The Observer UI will pop up in a new window. (And to close this down we
can just use the `:observer.stop/0` function.)

Now, there's an awful lot going on here. But for the purposes of this
tutorial we're just going to look at the Table Viewer tab.

Now, we're going to inspect some tables. We might need to click on the
Table Name header to sort the tables. For our purposes let's open the
table we created `Elixir.TestQuery.florence`. And this is what we should
see:

Now each row can be separately inspected just by clicking on it.

And just by way of showing that what we can write into an ETS table we
can also read out. This `read_table/1` function just trivially prints
out one of the terms (the RDF object value) stored in a table.
Interesting here is the pattern matching on the tuple to very simply get
at one of the terms.

```elixir
# lib/test_query/client.ex
def read_table(table_name) do
  :ets.tab2list(table_name) |> Enum.each(&_read_tuple/1)
end

defp _read_tuple(tuple) do
  {_, _, _, o, _} = tuple
  IO.puts o
end
```
We can just run this as follows:

```bash
bash> make all

iex> read_table(:"Elixir.TestQuery.Client.beryl")
#=> http://en.wikipedia.org/wiki/Hurricane_Beryl
    Hurricane Beryl
    319222358
    http://en.wikipedia.org/wiki/Hurricane_Beryl?oldid=319222358
    1848146
    nodeID://b8848505
    http://dbpedia.org/resource/Tropical_Storm_Beryl
    http://dbpedia.org/resource/Tropical_Storm_Beryl
    :ok
```

Note the quoting on the ETS table name `:"Elixir.TestQuery.Client.beryl"`.

The final of version `lib/test_query/client.ex`:

```elixir
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

  ## Accessors for module attributes

  @doc false
  def get_query, do: @query

  @doc false
  def get_service, do: @service

  ## Hello query to test access to remote RDF datastore

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

  ## Simple remote query functions

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

  ## Demo of multiple SPARQL queries: from RQ files to ETS tables

  @doc """
  Queries default RDF service with saved SPARQL queries.

  This function also stores results in per-query ETS tables.
  """
  def rquery_all do
    # get list of query files
    query_files =
      Path.wildcard(@query_dir <> "*.rq") |> Enum.map(&Path.basename/1)

    # iterate over query files and process
    for query_file <- query_files,
      do: _read_query(query_file) |> _get_data
  end

  @doc """
  Reads RDF data from ETS table and prints it.
  """
  def read_table(table_name) do
    :ets.tab2list(table_name) |> Enum.each(&_read_tuple/1)
  end

  @doc false
  defp _read_query(query_file) do
    # output a progress update
    IO.puts "Reading #{query_file}"

    # read query from query_file
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
    # output a progress update
    IO.puts "Writing #{table_name}"

    # create ETS table
    :ets.new(table_name, [:named_table])

    # now call SPARQL endpoint and populate ETS table
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
    # need to test type of object term
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
```

It's shown here how the `SPARQL.ex` and `SPARQL.Client.ex` packages can
be used for querying RDF datastores in Elixir.

Specifically we've used `SPARQL.ex` to query local (in-memory) RDF
models, and provided some convenience functions for further exploration.
We then used `SPARQL.Client.ex` to query remote RDF datastores and again
provided some convenience functions for further testing.

We then proceeded to develop a small demo which read stored SPARQL
queries, applied them to a remote SPARQL endpoint and then saved the
results in the Erlang runtime as ETS tables to inspect the result sets
using the wonderful Observer tool.

Introducing the Observer brings us that little closer to the Erlang
system in flight with its process tree. It is this very granular process
model which allows us to think about new solutions using a distributed
compute paradigm for semantic web applications. I hope to be able to
follow up on some of this promise in future it.

### 6 November 2018 by Oleg G.Kapranov

[1]: https://github.com/tonyhammond/examples/tree/master/test_query
[2]: https://medium.com/@tonyhammond/querying-rdf-with-elixir-2378b39d65cc
