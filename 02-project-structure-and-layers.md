# dbt Project Structure & Layers

## The standard folder layout, and why each folder exists

```
dbt_demo_project/
├── dbt_project.yml     # project-wide config: names, paths, materialization defaults
├── seeds/               # small CSVs dbt loads directly (see 07-seeds-and-snapshots.md)
├── models/
│   ├── staging/          # 1:1 cleaned versions of raw sources
│   └── marts/             # joined, business-ready tables
├── snapshots/            # SCD Type 2 history tracking
├── macros/                # reusable Jinja/SQL logic
└── tests/                  # singular (custom) tests
```

This mirrors the medallion architecture from `data-pipeline-concepts`
almost exactly: `seeds`/raw sources = bronze, `staging` = silver,
`marts` = gold.

## Why staging and marts are separate folders, not one flat `models/`

This is the single most consequential structural decision in a dbt
project, and it's worth understanding *why*, not just copying the
convention.

**Staging models have one job: clean a single source, 1:1.**
`stg_customers.sql` in this project touches only `raw_customers` — no
joins to orders, no joins to products, no business logic. This
project's real file demonstrates the boundary clearly: it dedupes,
coalesces nulls, and applies casing standardization — nothing else.

**Marts models have a different job: join and apply business logic.**
`fct_sales.sql` joins three staging models together, excludes
cancelled orders (a business decision, not a data-cleaning one), and
derives `revenue_tier`. It never touches `raw_orders` directly — only
`stg_orders`.

**Why this separation matters in practice, not just in theory:** if
`fct_sales` looks wrong, the folder structure itself tells you where
to look first. Is a staging model producing bad data (check
`staging/`)? Or is the join/business logic itself wrong (check
`marts/`)? Without the separation, both concerns live in one tangled
file, and every debugging session starts from zero instead of a clear
first question.

## `dbt_project.yml` — setting defaults instead of repeating config

```yaml
models:
  quickbyte_dbt_demo:
    staging:
      +materialized: view
    marts:
      +materialized: table
```
This says: every model under `models/staging/` is a view unless a
specific model overrides it; every model under `models/marts/` is a
table unless overridden. `fct_sales.sql` in this project *does*
override it, via an explicit `{{ config(materialized='incremental')
}}` block at the top of the file — demonstrating that
folder-level defaults are just that, defaults, not hard rules.

## Why staging = view, marts = table (the default choice, and when to break it)

**Views cost nothing to store and are always fresh** — since a view
just re-runs its query on every read, there's no stale-data risk and
no storage overhead. Staging models are cheap to keep as views because
they're rarely queried directly by end users (marts are what BI tools
point at) — the view's slightly-slower read speed almost never matters
for an intermediate layer.

**Marts are materialized as tables because they ARE queried directly**
by BI tools and analysts, often repeatedly, often by non-technical
users who shouldn't have to wait for a complex multi-join query to
re-run on every single dashboard refresh. Paying the storage/build cost
once, and serving fast reads after, is the right trade for a
frequently-queried layer.

## Naming conventions used in this project (and why)

- `stg_<source_name>` — staging models, one per raw source
- `fct_<subject>` — fact tables (transaction-grain, one row per event —
  here, one row per order)
- `raw_<source_name>` — seed files / raw source tables

Consistent prefixes matter more than they might seem to: once a
project has 50+ models, `stg_` vs `fct_` vs `dim_` (dimension tables,
not used in this small demo but standard in larger projects) lets
anyone browsing the file list immediately understand a model's role
without opening it — the same reasoning behind consistent naming in
any codebase, just applied to SQL files instead of application code.
