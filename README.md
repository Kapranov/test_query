# TestQuery

**TODO: Add description**

Using SPARQL.ex to query over RDF datastores with SPARQL. So let's
have a look at that. In there are two separate packages: `SPARQL.ex`
for querying in-memory RDF models, and `SPARQL.Client.ex` for
dispatching queries to remote RDF models. So let's first deal with
local (in-memory) models and then go on to remote models.

## Create a project

First off, let's create a new project `TestQuery` using the usual Mix
build tool invocation: `mkdir test_query; cd test_query; mix new .`

### 6 November 2018 by Oleg G.Kapranov
