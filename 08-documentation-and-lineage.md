# Documentation & Lineage

## `dbt docs generate` — documentation derived from the code, not written separately

```bash
dbt docs generate
dbt docs serve
```
This reads every model's SQL, every `description:` field in
`schema.yml`, every test, and every `ref()`/`source()` call, and
builds a browsable, searchable site — including an interactive
dependency graph (the "DAG view") showing exactly how data flows from
seeds through staging into marts.

**Why this matters more than it might first appear:** documentation
that lives in a separate wiki/Confluence page inevitably drifts out of
sync with the actual code — someone changes a model, forgets to update
the wiki, and six months later the docs are actively misleading. Since
dbt's docs are *generated from the project itself* on every
`docs generate` run, they can never be more stale than the last time
that command was run against the current code — structurally
impossible for the docs to describe a model that no longer exists.

## What the generated lineage graph actually shows, for this project

Running `dbt docs generate` against this repo's `dbt_demo_project`
produces a DAG with this exact shape:
```
raw_customers ──┐
raw_orders ─────┼──> stg_customers, stg_orders, stg_products ──> fct_sales
raw_products ───┘
```
This isn't hand-drawn — it's mechanically derived from the `ref()`
calls in every model. If a new model were added tomorrow that joins
`fct_sales` with a new `dim_time` model, the graph would update
automatically on the next `docs generate` — no diagram to remember to
redraw.

## Model and column descriptions — the other half of documentation

```yaml
models:
  - name: fct_sales
    description: "Order-grain fact table. Incremental materialization. Cancelled orders excluded."
    columns:
      - name: revenue_tier
        description: "..."
```
These `description:` fields (used throughout this project's
`models/schema.yml`) show up directly in the generated docs site next
to each model/column — meaning a new team member (or a recruiter
exploring the repo) can understand what `revenue_tier` means and how
it's derived without reading the SQL itself, or asking someone who
remembers.

## Exposures — documenting what's downstream of dbt

```yaml
exposures:
  - name: sales_dashboard
    type: dashboard
    depends_on:
      - ref('fct_sales')
    owner:
      name: Analytics Team
```
Not used in this small demo project, but worth knowing: exposures let
a dbt project document things that consume its output but aren't
themselves dbt models — a BI dashboard, a downstream ML pipeline, an
API. This closes the loop on lineage: not just "where did this data
come from" but "what would break if I changed this model" — genuinely
useful before making a risky schema change to a widely-used mart.

## The interview-relevant point

"We have good documentation" is a claim every team makes and almost
none actually deliver on, because manually-maintained docs rot. The
honest, differentiated answer is naming *why* dbt's docs don't rot the
same way — they're generated from the same source of truth as the
code that would need reviewing anyway, not a parallel artifact someone
has to remember to update.
