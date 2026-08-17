-- fct_sales.sql
-- Mart layer: joined, business-ready. Deliberately configured as
-- 'incremental' (rather than inheriting the project default 'table'
-- from dbt_project.yml) to demonstrate the incremental pattern for
-- real -- see docs/09-incremental-models-in-depth.md for the full
-- explanation of what is_incremental() does and why the watermark
-- filter only applies on incremental runs, not the first full build.

{{
    config(
        materialized='incremental',
        unique_key='order_id'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),
customers as (
    select * from {{ ref('stg_customers') }}
),
products as (
    select * from {{ ref('stg_products') }}
)

select
    o.order_id,
    o.order_date,
    o.ship_date,
    date_diff('day', o.order_date, o.ship_date) as days_to_ship,
    o.order_status,
    o.sales_amount,
    c.customer_id,
    c.first_name as customer_name,
    c.country as customer_country,
    p.product_id,
    p.product_name,
    p.category as product_category,
    case
        when o.sales_amount >= 200 then 'High'
        when o.sales_amount >= 80 then 'Medium'
        else 'Low'
    end as revenue_tier
from orders o
left join customers c on o.customer_id = c.customer_id
left join products p on o.product_id = p.product_id
where o.order_status != 'Cancelled'

{% if is_incremental() %}
    -- On an incremental run, only process orders newer than what's
    -- already in the target table -- this is the entire mechanism
    -- that makes incremental models fast on large fact tables: skip
    -- reprocessing rows that haven't changed.
    and o.order_date > (select max(order_date) from {{ this }})
{% endif %}
