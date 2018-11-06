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

### 6 November 2018 by Oleg G.Kapranov

[1]: https://github.com/tonyhammond/examples/tree/master/test_query
[2]: https://medium.com/@tonyhammond/querying-rdf-with-elixir-2378b39d65cc
