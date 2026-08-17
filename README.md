# dbt_project

# dbt Deep Dive — ETL/ELT Transformation, Explained and Run

A depth-first companion to this series' SQL and AWS pipeline projects,
focused specifically on dbt: what it is, why each of its features
exists, and — unlike a typical dbt tutorial — **every single claim in
this repo's docs is backed by a real command run against a real
(free, local) database**, not just described.

**No cloud account needed.** This project runs on DuckDB, an
in-process SQL database — clone this repo and you can run the entire
pipeline in under a minute with zero signup, zero credentials, zero
cost.

## Why this project exists

The other two projects in this series (`sql-portfolio-quickbyte`,
`sales-data-pipeline`) prove I can write production-shaped SQL and
build a real AWS-based pipeline. This project goes one level deeper on
specifically **dbt** — the tool that sits at the center of the modern
ELT pattern — with genuine, runnable proof for every concept, so
nothing here is a claim taken on faith.

## Run it yourself (takes about 60 seconds)

```bash
git clone <this-repo>
cd dbt-deep-dive/dbt_demo_project
pip install dbt-core dbt-duckdb

dbt seed              # loads 3 small CSVs (customers, orders, products)
dbt run               # builds 3 staging views + 1 incremental fact table
dbt test              # runs 12 data quality tests
dbt snapshot           # runs the SCD Type 2 snapshot
```

## Verified output — real runs, not illustrative examples

**`dbt run`:**
```
1 of 4 OK created sql view model main.stg_customers ............. [OK in 0.16s]
2 of 4 OK created sql view model main.stg_orders ................ [OK in 0.15s]
3 of 4 OK created sql view model main.stg_products ............... [OK in 0.14s]
4 of 4 OK created sql incremental model main.fct_sales ............ [OK in 0.10s]
Done. PASS=4 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=4
```

**`dbt test` — all 12 passing:**
```
Done. PASS=12 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=12
```

**The resulting `fct_sales` table** (queried directly — 7 raw orders
in, 1 cancelled order excluded, 1 exact duplicate deduplicated,
customer names properly title-cased via a custom macro):
```
order_id  customer_name    product_name     sales_amount  revenue_tier  order_status
101       Ana Garcia       Classic Burger    89.50        Medium        Delivered
102       Lukas Meyer      Loaded Fries      210.00       High          Delivered
104       Ana Garcia       Chocolate Shake   132.75       Medium        Delivered
105       Marco Rossi      Loaded Fries      410.00       High          Pending
106       Elena Popescu    Chocolate Shake   58.20        Low           Delivered
```

**SCD Type 2 snapshot, proven with a real before/after** — customer 1
was changed from Germany to France in the source data, then
`dbt snapshot` was re-run:
```
customer_id  country  dbt_valid_from        dbt_valid_to
1            germany  2026-08-16 23:47:52   2026-08-16 23:48:07   <- closed, not deleted
1            france   2026-08-16 23:48:07   NULL                  <- new current row
```
Both rows exist. History is preserved, not overwritten — exactly what
SCD Type 2 promises, verified rather than asserted.

## Start here — the 10 concept docs

| Doc | Covers |
|---|---|
| [`01-what-is-dbt-and-why.md`](docs/01-what-is-dbt-and-why.md) | What dbt actually does, why it's ELT's "T", why this project uses DuckDB |
| [`02-project-structure-and-layers.md`](docs/02-project-structure-and-layers.md) | Why staging/marts are separate folders, and what breaks if you skip that |
| [`03-materializations.md`](docs/03-materializations.md) | View/table/incremental/ephemeral — what each costs and when to use it |
| [`04-sources-seeds-and-ref.md`](docs/04-sources-seeds-and-ref.md) | The `ref()` vs `source()` distinction that trips up most beginners |
| [`05-testing-in-dbt.md`](docs/05-testing-in-dbt.md) | Generic vs singular tests, with this project's real 12 tests as examples |
| [`06-macros-and-jinja.md`](docs/06-macros-and-jinja.md) | Includes a real debugging story: a macro bug caught by actually running the pipeline |
| [`07-seeds-and-snapshots.md`](docs/07-seeds-and-snapshots.md) | SCD Type 2, with the real before/after shown above |
| [`08-documentation-and-lineage.md`](docs/08-documentation-and-lineage.md) | Why `dbt docs generate` can't go stale the way a wiki page can |
| [`09-incremental-models-in-depth.md`](docs/09-incremental-models-in-depth.md) | The late-arriving-data problem incremental models introduce, and how to handle it |
| [`10-environments-and-ci-cd.md`](docs/10-environments-and-ci-cd.md) | Why this project's CI can safely run the *full* pipeline, unlike the AWS project's |

## Repo structure

```
dbt-deep-dive/
├── docs/                          # the 10 concept docs + sprint plan
├── dbt_demo_project/
│   ├── seeds/                     # 3 small CSVs, deliberately messy
│   ├── models/
│   │   ├── staging/                # stg_customers, stg_orders, stg_products
│   │   └── marts/fct_sales.sql      # incremental fact table
│   ├── snapshots/customers_snapshot.sql   # SCD Type 2
│   ├── macros/title_case.sql        # custom reusable macro
│   ├── tests/assert_no_negative_sales.sql # singular test
│   ├── dbt_project.yml
│   └── profiles.yml                  # points at a local DuckDB file, no credentials needed
└── .github/workflows/ci.yml            # runs the FULL pipeline (seed/run/test/snapshot) on every push
```

## How this connects to the other two projects in this series

| Concept | Where else it appears |
|---|---|
| ELT pattern, medallion architecture | `data-pipeline-concepts` — this project is that theory, made runnable |
| dbt against a real cloud warehouse (Athena) | `sales-data-pipeline/dbt_project/` — the production-shaped sibling to this DuckDB demo |
| Why that project's CI only runs `dbt parse`, not a full run | `sales-data-pipeline/docs/decisions.md` (ADR-6) — contrast with this project's CI, which safely runs everything since there are no cloud secrets involved |
| Full SQL fundamentals underlying every model here | `sql-portfolio-quickbyte` |

## A note on how this was built

Same discipline as the rest of this series: drafted with an AI
assistant, but every single code example was actually executed — not
just written — before being documented as fact, including catching and
fixing a real bug in the `title_case` macro along the way (see
`06-macros-and-jinja.md` for that story in full). The verified output
throughout this README and the docs is real, current, and
reproducible by anyone who clones the repo and runs the four commands
above.
