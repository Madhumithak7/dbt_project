{% snapshot customers_snapshot %}
{#-
    SCD Type 2 in practice: dbt compares each snapshot run's incoming
    data against the current snapshot state. If a tracked column
    (here: country, score) has changed for a customer_id, dbt closes
    out the old row (setting dbt_valid_to) and inserts a new row
    (with dbt_valid_from = now), instead of overwriting in place.
    Run `dbt snapshot` to execute this -- see
    docs/07-seeds-and-snapshots.md for the full walkthrough of what
    happens on the first run vs. a later run after the source data
    changes.
-#}
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
