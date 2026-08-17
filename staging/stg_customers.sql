-- stg_customers.sql
-- Staging layer: 1:1 with the raw seed, cleaned but not joined to
-- anything else. Demonstrates: source() reference, a custom macro
-- call, and null handling with coalesce.

with source as (
    select * from {{ ref('raw_customers') }}
)

select
    customer_id,
    {{ title_case('first_name') }} as first_name,
    {{ title_case('country') }} as country,
    coalesce(score, 0) as score
from source
where customer_id is not null
