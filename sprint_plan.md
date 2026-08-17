# Sprint Plan

Same format as the other two projects in this series — copy into a
GitHub Projects board and screenshot it as proof-of-process for the
portfolio site.

## Sprint 0 — Scoping (2 points)

| Task | Points | Acceptance Criteria |
|---|---|---|
| Decide on DuckDB over a cloud warehouse | 1 | Reasoning documented in README — zero-infrastructure, fully reproducible for any reader |
| Design seed data with deliberate messiness | 1 | `seeds/*.csv` include a duplicate order, null scores, inconsistent casing — matching this series' other demo data |

## Sprint 1 — Core project build (8 points)

| Task | Points | Acceptance Criteria |
|---|---|---|
| Write staging models (customers, orders, products) | 3 | `dbt run` builds all 3 as views with no errors |
| Write the custom `title_case` macro | 2 | Called from `stg_customers`; output verified correct on multi-word values |
| Write `fct_sales` mart with incremental materialization | 3 | `dbt run` builds it; cancelled orders confirmed excluded by inspecting real output |

## Sprint 2 — Testing (5 points)

| Task | Points | Acceptance Criteria |
|---|---|---|
| Add generic tests (unique/not_null/accepted_values/relationships) | 3 | `dbt test` passes 12/12 |
| Add a singular test for a business rule generic tests can't express | 2 | `assert_no_negative_sales.sql` passes against real data |

## Sprint 3 — Snapshots (3 points)

| Task | Points | Acceptance Criteria |
|---|---|---|
| Write the SCD Type 2 snapshot | 2 | `dbt snapshot` runs without error |
| Prove history preservation with a real before/after | 1 | Source data changed, snapshot re-run, both old and new rows verified present with correct `dbt_valid_from`/`dbt_valid_to` |

## Sprint 4 — Docs & CI/CD (7 points)

| Task | Points | Acceptance Criteria |
|---|---|---|
| Write the 10 concept docs | 4 | Each doc references real output from this project, not just abstract claims |
| Write GitHub Actions CI running the full pipeline | 2 | A PR with a broken test shows a red X before merge |
| Write the README tying everything together | 1 | A first-time reader can run the whole project from the README alone |

## Total: 25 story points

**A deliberate scope note, consistent with the rest of this series:**
this sprint plan does NOT include a "Sprint 5: cloud warehouse
deployment" — that's out of scope by design. This project's entire
value proposition is being runnable by anyone, instantly, with zero
cloud setup. Adding an optional cloud target would be a reasonable
future extension, but isn't part of this project's Definition of Done.
