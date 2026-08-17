# Materializations — Views, Tables, Incremental, Ephemeral

## What "materialization" means

The strategy dbt uses to turn your `SELECT` statement into something
that actually persists (or doesn't) in the warehouse. Set globally in
`dbt_project.yml`, per-model in a `config()` block, or both (model
config always wins over project defaults — this project's
`fct_sales.sql` demonstrates exactly that override).

## View

```sql
{{ config(materialized='view') }}
```
Creates a database view — the query re-runs every time the view is
read. No storage cost beyond the query definition itself; always
reflects the current state of its underlying tables. **Cost:** slower
to query than a table, since the full logic re-executes on every read.

**Used for:** staging models in this project (`02-project-structure-
and-layers.md` explains why).

## Table

```sql
{{ config(materialized='table') }}
```
Runs the query once, stores the full result set as a real table. Fast
to query afterward — no re-computation on read. **Cost:** storage, and
staleness — the table only reflects data as of the last `dbt run`, not
live.

**Used for:** the default for `marts/` in this project.

## Incremental

```sql
{{ config(materialized='incremental', unique_key='order_id') }}
```
The most operationally important materialization for real-scale data,
and the one this project's `fct_sales.sql` actually uses. Instead of
rebuilding the entire table on every run, an incremental model
processes **only new/changed rows** and merges them into the existing
table using `unique_key` to match rows for update-vs-insert.

**The `is_incremental()` macro is the mechanism that makes this work:**
```sql
{% if is_incremental() %}
    and o.order_date > (select max(order_date) from {{ this }})
{% endif %}
```
This block is **skipped entirely on the first run** (the table doesn't
exist yet, so there's nothing to be incremental *relative to* — dbt
does a full build). On every subsequent run, `is_incremental()`
evaluates true, and the `WHERE` filter kicks in, so only rows newer
than what's already in the target get processed. `{{ this }}` refers
to the model's own already-built table — a self-reference that only
makes sense in this incremental context.

**Why this matters at real scale, concretely:** picture a `fct_sales`
table with 500 million historical rows. A `table` materialization
would re-scan and rebuild all 500 million rows on every single run,
even if only 10,000 new orders came in today. An `incremental` model
processes only those 10,000 — the difference between a job that takes
seconds and one that takes hours, at scale.

**The genuine trade-off:** incremental models are more complex to
reason about (see `09-incremental-models-in-depth.md` for the full
treatment, including the "what if I need to reprocess history"
problem), and a subtly wrong watermark condition can silently skip or
duplicate rows. Don't default to incremental for small tables where a
full rebuild is fast and simple — reach for it specifically when table
size makes full rebuilds genuinely too slow or too expensive.

## Ephemeral

```sql
{{ config(materialized='ephemeral') }}
```
Not materialized as a database object **at all** — dbt inlines the
model's SQL as a CTE directly into whatever references it, at compile
time. No table, no view, nothing queryable on its own in the warehouse.

**Used for:** small, intermediate logic steps that exist purely to
keep a larger model's SQL readable (breaking one giant query into
named pieces) but that nobody needs to query independently — e.g. a
reusable filter or a small lookup calculation referenced by exactly
one downstream model.

**The trade-off:** because nothing is materialized, ephemeral models
can't be queried directly for debugging (you can't just `SELECT *
FROM` an ephemeral model in the warehouse — it doesn't exist there),
which makes them harder to inspect mid-pipeline than a view. Use
sparingly, for genuinely small glue logic, not as a default choice.

## Decision guide

| Situation | Materialization |
|---|---|
| Small/cheap query, always needs to be current | view |
| Frequently queried by BI tools/analysts | table |
| Large fact table, full rebuild is too slow | incremental |
| Small reusable logic snippet, never queried standalone | ephemeral |
