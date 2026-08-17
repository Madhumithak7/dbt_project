-- stg_orders.sql
-- Demonstrates the exact dedup pattern used throughout this repo
-- series: row_number() over a partition, keep rn = 1. The seed data
-- deliberately contains one exact-duplicate order_id (105) to give
-- this logic something real to catch -- verified in
-- dbt_demo_project's schema.yml via a unique test on order_id.

with source as (
    select * from {{ ref('raw_orders') }}
),

deduplicated as (
    select
        *,
        row_number() over (partition by order_id order by order_id) as rn
    from source
)

select
    order_id,
    customer_id,
    product_id,
    cast(order_date as date) as order_date,
    cast(ship_date as date) as ship_date,
    status as order_status,
    cast(sales_amount as decimal(10,2)) as sales_amount
from deduplicated
where rn = 1
  and order_id is not null
