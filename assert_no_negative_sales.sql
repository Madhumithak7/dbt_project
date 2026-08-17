-- assert_no_negative_sales.sql
-- Singular test: a standalone SQL file in tests/ that dbt runs as a
-- test automatically. dbt's convention: if this query returns ANY
-- rows, the test FAILS -- the query should express "find the bad
-- rows," not "assert true/false" directly. This is for business
-- rules too specific for schema.yml's generic tests (unique/not_null/
-- accepted_values/relationships) to express -- see
-- docs/05-testing-in-dbt.md for when to reach for a singular test
-- versus a generic one.

select order_id, sales_amount
from {{ ref('fct_sales') }}
where sales_amount < 0
