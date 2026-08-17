# Seeds & Snapshots

## Seeds — recap and mechanics

Covered in `04-sources-seeds-and-ref.md` conceptually; mechanically,
`dbt seed` reads every `.csv` in `seeds/`, infers column types, and
loads each one as a table named after the file (`raw_customers.csv` →
a `raw_customers` table). Re-running `dbt seed` fully replaces the
table's contents — seeds are not incremental or append-only.

## Snapshots — SCD Type 2, implemented and actually verified

Covered conceptually in `data-pipeline-concepts/docs/06-slowly-
changing-dimensions.md`. This section shows dbt's specific mechanism
for it, **with real before/after output** — not a hypothetical.

### The snapshot definition

```sql
{% snapshot customers_snapshot %}
{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='check',
        check_cols=['country', 'score'],
    )
}}
select * from {{ ref('raw_customers') }}
{% endsnapshot %}
```
`strategy='check'` tells dbt: "compare the columns listed in
`check_cols` between this run's incoming data and the current snapshot
state — if any of them differ for a given `unique_key`, treat this as
a change." (The alternative, `strategy='timestamp'`, instead compares
an `updated_at`-style column's value — appropriate when the source
already reliably tracks its own last-modified time; `check` is the
right choice when it doesn't.)

### What happened when this was actually run

**First `dbt snapshot` run** — every customer gets one row, `dbt_valid_from`
set to the run time, `dbt_valid_to` empty (still current):
```
customer_id  country  score  dbt_valid_from              dbt_valid_to
1            germany  450    2026-08-16 23:47:52         NULL
2            Germany  NULL   2026-08-16 23:47:52         NULL
...
```

**Then customer 1's country was changed from `germany` to `france`** in
the source CSV (simulating a real customer relocating), and `dbt seed`
+ `dbt snapshot` were run again. Real result:
```
customer_id  country  dbt_valid_from              dbt_valid_to
1            germany  2026-08-16 23:47:52         2026-08-16 23:48:07
1            france   2026-08-16 23:48:07         NULL
```
**This is SCD Type 2 working exactly as designed:** the original
`germany` row was NOT overwritten — it was closed out
(`dbt_valid_to` populated with the moment the change was detected),
and a new `france` row was inserted as the new "current" version
(`dbt_valid_to` still NULL). Any fact table joined against this
snapshot at a specific point in time would correctly show
`germany` for anything that happened before 23:48:07, and `france`
for anything after — full history preserved, nothing lost.

### Why this matters beyond the mechanics

This is the exact capability that makes "what did this customer's
country look like when this specific order was placed" an answerable
question, months or years later — a plain `UPDATE`-based dimension
table (SCD Type 1) could never answer that, because the old value
would already be gone.

### The trade-off, stated honestly

Every snapshot run that finds a change adds a row — over years of
operation with frequently-changing dimensions, this table grows
continuously and never shrinks (unlike a normal table, there's no
natural "current state only" size ceiling). This is the direct cost of
SCD Type 2's benefit, and it's why `06-slowly-changing-dimensions.md`
in the companion concepts repo frames Type 2 as "the default when in
doubt," not "always use this regardless of the data's actual change
frequency" — a dimension that changes every run for every row would
make this trade-off much less favorable.
