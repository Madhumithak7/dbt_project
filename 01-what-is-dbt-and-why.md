# What is dbt, and Why It Exists

## What dbt actually is

dbt (data build tool) is **not** a data pipeline tool in the sense of
Airflow or Fivetran — it doesn't extract data from anywhere, and it
doesn't move data between systems. dbt does exactly one job: it takes
SQL `SELECT` statements you write, and turns them into `CREATE TABLE
AS SELECT` / `CREATE VIEW AS SELECT` statements it runs **against a
warehouse that already has raw data loaded into it.**

This is the direct implementation of the ELT pattern's "T" — see this
repo series' `data-pipeline-concepts/docs/02-elt-explained.md` for the
full ELT explanation. dbt is, quite literally, what most teams mean
when they say "we do ELT."

## The core mental model

You write a `.sql` file containing a `SELECT` statement. dbt wraps it
in `CREATE TABLE/VIEW AS` and runs it. That's the whole primitive —
everything else in dbt (tests, docs, snapshots, incremental logic,
macros) is built as scaffolding around that one core idea.

```sql
-- models/staging/stg_customers.sql
select customer_id, first_name, country
from {{ ref('raw_customers') }}
```
dbt compiles this into real SQL, resolving `{{ ref(...) }}` into the
actual table name in your warehouse, and runs it. Nothing more exotic
is happening under the hood than that.

## Why dbt specifically, and not just hand-written SQL scripts

**Dependency management is automatic.** `stg_customers` references
`raw_customers` via `ref()`. If a downstream model (`fct_sales`)
references `stg_customers`, dbt automatically figures out the correct
build order — you never have to manually sequence `CREATE TABLE`
statements or remember which script has to run before which.

**Version control and code review become possible for transformation
logic.** SQL that used to live as ad-hoc scripts run manually, or
buried inside a BI tool's saved query, becomes a `.sql` file in Git —
reviewable in a pull request, diffable, revertable.

**Testing is built in, not bolted on.** `dbt test` runs assertions
against real materialized data as part of the normal workflow — see
`05-testing-in-dbt.md`.

**Documentation is generated from the same source of truth as the
code.** `dbt docs generate` builds a browsable data dictionary and
dependency graph directly from your models and `schema.yml` — no
separately-maintained wiki page that drifts out of sync with reality.

## Why this project runs on DuckDB, not a cloud warehouse

Every other project in this repo series (`sales-data-pipeline`) uses
dbt against AWS Athena — but that requires an AWS account, S3 bucket,
and Glue Catalog to actually execute. **This project uses DuckDB
instead**, a free, in-process SQL database that needs zero
infrastructure and zero signup. The entire point of this specific
repo is to let anyone — including a recruiter with five minutes and no
AWS credentials — clone it and run `dbt run && dbt test` themselves
and watch it actually work. See the README's "Run it yourself"
section for the exact commands; every code example in this docs
series was run for real to produce the output quoted throughout.

## What dbt is not

Worth naming explicitly, since it comes up in interviews: dbt does
not extract data from source systems (that's Fivetran/Airbyte/custom
scripts), does not orchestrate *when* things run on a schedule
(that's Airflow/Dagster — though dbt Cloud has its own limited
built-in scheduler), and does not store data itself (the warehouse
does that; dbt just issues SQL against it). Confusing dbt's scope with
an orchestrator's scope is a common beginner mix-up worth avoiding
explicitly in an interview answer.
