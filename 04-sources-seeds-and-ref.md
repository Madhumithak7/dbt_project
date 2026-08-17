# Sources, Seeds, and `ref()` vs `source()`

## The distinction that trips up almost everyone starting dbt

dbt has **two** ways to reference "the first table in a chain," and
picking the wrong one is one of the most common beginner mistakes:

**`source()`** — references raw data that was loaded into the
warehouse by something *other than dbt* (Fivetran, Airbyte, a custom
Python script, CDC). dbt doesn't create this data; it just declares
"this table exists, here's what I call it, here's how fresh it should
be" via a `sources:` block in a `.yml` file.

**`ref()`** — references any model (or seed) that dbt itself builds.
This includes staging models, marts, AND seeds — because `dbt seed`
is dbt actually creating the table, `ref()` is the correct way to
point at it, not `source()`.

**Why this project's staging models use `ref('raw_customers')`, not
`source('raw', 'customers')`:** the raw data here comes from `dbt
seed` loading the CSVs in `seeds/` — dbt itself is doing the loading,
so these are seeds referenced via `ref()`, not sources. Contrast with
`sales-data-pipeline`'s dbt project (the AWS-based sibling to this
repo), where raw tables are populated by a Glue Crawler cataloging
data an entirely separate pipeline loaded into S3 — that's the
textbook case for `source()`, and that project's `models/schema.yml`
uses exactly that pattern.

## Why `ref()`/`source()` instead of just writing the table name directly

```sql
-- Don't do this:
select * from raw_customers

-- Do this:
select * from {{ ref('raw_customers') }}
```
Three concrete reasons, not just convention:

1. **Environment portability.** `ref()` resolves to whatever database/
   schema the current target points at (dev vs. prod, your local
   DuckDB file vs. a teammate's). Hard-coding a table name breaks the
   moment anyone runs the project against a different environment.
2. **Automatic dependency graph.** dbt parses every `ref()`/`source()`
   call to build the DAG of what depends on what — this is *how* dbt
   knows to build `stg_orders` before `fct_sales`. A hard-coded table
   name is invisible to this system entirely; dbt has no way to know
   the dependency exists.
3. **Lineage and impact analysis** (`dbt docs generate`, see
   `08-documentation-and-lineage.md`) are built directly from these
   references — hard-coded names produce a broken or incomplete
   lineage graph.

## Seeds — when to use them, and when not to

Seeds are for **small, mostly-static reference data that lives in
version control** — not for loading your actual operational data.
Good seed candidates: a country-code-to-region mapping, a list of
valid status codes, small lookup tables that rarely change. This
project's seeds (`raw_customers.csv`, `raw_orders.csv`,
`raw_products.csv`) are used here purely as a portable stand-in for
"data that would normally arrive via extraction" — specifically so
this project needs zero external infrastructure to run. In a real
production system, order/customer transactional data would never be a
seed — it would come from `source()`, populated by a real extraction
pipeline, precisely because it's neither small nor static.

## Source freshness — a feature specific to `source()`, not `ref()`

```yaml
sources:
  - name: raw
    tables:
      - name: orders
        loaded_at_field: _loaded_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
```
`dbt source freshness` checks whether a source table has actually been
updated recently — catching a silently-broken upstream extraction job
(the extraction "succeeded" with no errors, but hasn't actually
delivered new data in 2 days). This only applies to `source()`-declared
tables, since freshness is inherently about *external* data arriving
on schedule — a seed's "freshness" is just whatever's checked into Git,
which isn't a meaningful freshness question in the same sense.
