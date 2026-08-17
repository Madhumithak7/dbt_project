# Environments & CI/CD for dbt

## Targets — how one project runs against multiple environments

`profiles.yml` defines named **targets**, each pointing at a different
database/warehouse connection:
```yaml
quickbyte_dbt_demo:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'dev.duckdb'
```
This project only defines `dev` (kept simple deliberately, per the
scope note below) — a real production setup typically adds a `prod`
target pointing at the actual warehouse, and CI runs against a
dedicated `ci`/`test` target so pipeline validation never touches
production data. Switching targets is just `dbt run --target prod` —
the **same model code** runs unchanged against a different connection,
which is the entire point: transformation logic shouldn't need to
know or care which environment it's executing in.

## This project's actual CI pipeline — a genuine, running example

`.github/workflows/ci.yml` in this repo does something most portfolio
projects can't: **actually runs the full dbt pipeline in CI**, not
just a syntax check, because DuckDB needs no cloud credentials at all.
Every pull request against this repo really executes:
```
dbt seed   # loads the CSVs into a fresh DuckDB file
dbt run    # builds every staging + mart model
dbt test   # runs all 12 tests
```
If a PR introduces a bug — say, a change to `fct_sales.sql` that
accidentally re-includes cancelled orders — the `accepted_values` or
`relationships` test would fail right there in the GitHub Actions log,
blocking merge, with the exact failing test named in the output.

**Compare this to `sales-data-pipeline`'s CI** (the AWS-based sibling
project), which deliberately runs only `dbt parse` in CI rather than a
full `dbt run`/`dbt test` — documented explicitly in that project's
`docs/decisions.md` (ADR-6) as a security trade-off, since giving a
public repo's CI live AWS credentials is a real risk. **This project's
CI can safely go further** precisely because DuckDB is a local file,
not a cloud resource requiring secrets — a genuine advantage of the
tooling choice, worth naming explicitly if asked "why DuckDB" in an
interview.

## The general environment-separation principle, beyond this project's scope

A production dbt setup typically separates:
- **dev** — each developer's own isolated schema/database, so
  experimentation never risks shared data
- **CI/test** — an ephemeral or scoped environment, torn down or reset
  per run, used purely for automated validation
- **prod** — the real warehouse schema BI tools and analysts query

`{{ target.name }}` inside a model or macro lets logic branch based on
which environment is currently running — e.g. sampling only 1% of rows
in `dev` to keep local iteration fast, while `prod` processes the full
dataset. Not implemented in this small demo (out of scope for a
DuckDB-based project with no real data volume problem), but worth
naming as the standard pattern at team scale.

## Why this project intentionally stays single-environment

Adding a fake `prod` target here would demonstrate the *syntax* of
multi-environment config without demonstrating anything *real* — there's
no actual second warehouse to point it at without reintroducing the
cloud-account dependency this project specifically avoids. Better to
be explicit about that scope boundary (as here) than to pad the
project with unused configuration that doesn't reflect genuine
production reasoning.
