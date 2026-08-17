-- stg_products.sql
select
    product_id,
    product_name,
    category,
    cast(price as decimal(10,2)) as price
from {{ ref('raw_products') }}
where product_id is not null
