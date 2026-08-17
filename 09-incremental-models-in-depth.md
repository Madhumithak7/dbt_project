# Incremental Models — In Depth

## Recap of the mechanism (from `03-materializations.md`)

`is_incremental()` gates a `WHERE` clause that only runs on non-first
builds, filtering to rows newer than what's already in the target
table (`{{ this }}`). This project's `fct_sales.sql` demonstrates this
for real — verified: the model built successfully both as a full table
(first run) and would apply the incremental filter on any subsequent
run.

## The hard problem incremental models introduce: late-arriving/backfilled data

If an incremental model's watermark is `order_date > max(order_date)
in the target`, what happens when a row arrives **late** — say, an
order from three days ago that only just got extracted due to an
upstream delay? Its `order_date` is *older* than the current max in
the target table, so the naive watermark filter would **silently skip
it forever.** This is one of the most common real production
incremental-model bugs, and it's worth understanding precisely because
it doesn't throw an error — the pipeline runs green while quietly
dropping data.

**Mitigations, in order of how commonly they're used:**

1. **Widen the watermark with a lookback window** — instead of `>
   max(order_date)`, use `> max(order_date) - interval '3 days'`,
   reprocessing a few days of overlap on every run. `unique_key` on
   the incremental config (used in this project) means re-processed
   rows correctly *update* existing rows rather than duplicating them
   — this is exactly why `unique_key` isn't optional for a
   correctness-sensitive incremental model.
2. **Use a strictly-increasing load/extraction timestamp instead of a
   business date** — e.g. filter on `_extracted_at`, which by
   definition can't be "late" the way a business event date can,
   since it's assigned at extraction time, not event time.
3. **Full-refresh periodically** — `dbt run --full-refresh` forces a
   complete rebuild, ignoring the incremental logic entirely. Some
   teams schedule this monthly as a safety net specifically to catch
   and correct any late-arriving data the watermark logic missed
   during the month.

## `--full-refresh` — when and why you actually need it

Beyond periodic safety-net rebuilds, `--full-refresh` is **required**,
not optional, whenever:
- the model's `SELECT` logic itself changes in a way that affects
  historical rows (e.g. fixing a bug in `revenue_tier`'s thresholds
  means every already-materialized row has the *old*, wrong tier —
  the incremental filter would never touch those old rows again to
  correct them)
- the `unique_key` or schema changes
- the incremental table needs to be rebuilt from scratch for any
  reason (data corruption, a testing reset)

**A genuinely common mistake:** fixing a bug in an incremental model's
transformation logic, running a normal `dbt run`, and being confused
when historical data still shows the old, buggy values. The fix only
applies to *newly processed* rows going forward — a `--full-refresh`
is what actually corrects history.

## Incremental strategies (briefly — warehouse-dependent)

Different warehouses support different incremental *strategies*
(`merge`, `delete+insert`, `append`, `insert_overwrite`), configurable
via `incremental_strategy` in the model config. DuckDB (used in this
project) defaults to a delete+insert-style approach; Snowflake/
BigQuery support a true `merge`. The conceptual behavior (`unique_key`-
based upsert) is the same across warehouses — the exact SQL dbt
generates under the hood differs based on what the target warehouse
actually supports efficiently.

## The honest trade-off summary

Incremental models trade **simplicity and correctness-by-default**
(a full table rebuild is trivially correct — it recomputes everything,
every time) for **speed at scale**. The late-arriving-data problem
above is the direct cost of that trade — it's not a flaw unique to
this project's implementation, it's inherent to the incremental
pattern itself, and any team adopting incremental models needs an
explicit answer for how they handle it, not just an assumption that
"the watermark will catch everything."
