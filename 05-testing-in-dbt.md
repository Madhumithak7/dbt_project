# Testing in dbt

## Two kinds of tests, and when each is the right tool

### Generic tests — declared in YAML, reusable across any column

```yaml
columns:
  - name: order_id
    tests:
      - unique
      - not_null
```
dbt ships four built-in generic tests: `unique`, `not_null`,
`accepted_values`, `relationships`. Each compiles into a `SELECT`
query that returns failing rows — if that query returns **zero rows**,
the test passes. Applied declaratively, no SQL to write by hand for
the common cases.

**This project's `models/schema.yml` uses all four**, verified for
real (12/12 passing in an actual run):
- `unique` + `not_null` on every table's primary key
- `accepted_values` on `order_status` (catches an unexpected status
  value slipping in) and `revenue_tier` (catches a bug in the tiering
  `CASE` logic producing an unexpected label)
- `relationships` on `fct_sales.customer_id` → `stg_customers.customer_id`
  (catches a broken join — an order referencing a customer that
  doesn't exist in the cleaned customer table)

### Singular tests — a standalone `.sql` file, for business rules generic tests can't express

```sql
-- tests/assert_no_negative_sales.sql
select order_id, sales_amount
from {{ ref('fct_sales') }}
where sales_amount < 0
```
Same pass/fail mechanism (zero rows = pass), but the query itself is
hand-written, so it can express any business rule at all — not just
the four built-in generic patterns. This project's
`assert_no_negative_sales.sql` is a real, running example: it passed
in the actual test run because none of the seed data has a negative
sales amount, but if it did, `dbt test` would fail loudly with the
exact offending `order_id` visible in the output.

## Deciding which kind to write — a genuine judgment call

**Reach for a generic test first, always** — if the rule is
expressible as uniqueness, not-null, a fixed value set, or a foreign-
key relationship, the generic test is less code, more readable, and
instantly reusable on other columns/models.

**Reach for a singular test when the rule is genuinely bespoke** — a
business rule involving a calculation, a cross-column comparison, or
logic specific enough that forcing it into a generic test's shape
would be more convoluted than just writing the SQL directly.

## What a failing test actually looks like, and why that's useful

If `assert_no_negative_sales` *did* fail, `dbt test` would print:
```
FAIL 1 assert_no_negative_sales ................ [FAIL 1 in 0.08s]
```
And running `dbt show` or looking at the compiled test's failing
rows shows exactly *which* `order_id` violated the rule — not just
"something is wrong somewhere," but the precise offending row,
immediately actionable.

## Where tests fit in a CI/CD pipeline

This project's `.github/workflows/ci.yml` runs `dbt seed`, `dbt run`,
and `dbt test` on every push — meaning a pull request that introduces
a transformation bug (e.g. accidentally re-including cancelled orders
in `fct_sales`) gets caught automatically, before merge, by the
`accepted_values` or `relationships` tests failing in CI — not
discovered days later by someone noticing a wrong number on a
dashboard. This is the same three-layer testing philosophy documented
in `data-pipeline-concepts/docs/09-data-quality-and-testing.md`,
here shown as dbt's specific, built-in implementation of it.
