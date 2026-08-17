# Macros & Jinja

## What Jinja is doing inside a dbt model

dbt models look like SQL but are actually **Jinja templates that
compile into SQL**. Every `{{ ... }}` and `{% ... %}` block is Jinja
templating syntax, resolved at compile time, before the SQL ever
reaches the warehouse. `{{ ref('stg_orders') }}` isn't SQL — it's a
Jinja function call that dbt evaluates and replaces with the actual
resolved table name (e.g. `"main"."stg_orders"`) before running
anything.

## Macros — functions, written once, reused everywhere

This project's `macros/title_case.sql`:
```sql
{% macro title_case(column_name) %}
    array_to_string(
        list_transform(
            string_split(lower(trim({{ column_name }})), ' '),
            word -> upper(word[1:1]) || word[2:]
        ),
        ' '
    )
{% endmacro %}
```
Called from `stg_customers.sql` twice — once for `first_name`, once
for `country`:
```sql
{{ title_case('first_name') }} as first_name,
{{ title_case('country') }} as country,
```

**Why this is worth doing instead of writing the SQL inline twice:**
if the casing logic ever needs to change (say, DuckDB gains a real
`initcap()` and the logic should simplify), there's exactly **one**
place to edit, and every model calling `title_case()` picks up the fix
automatically. Inline SQL duplicated across N models means N places to
remember to update, and N chances to update N-1 of them and introduce
an inconsistency.

## A genuine debugging story from building this exact project

The first version of this macro was a naive single-character approach
(`upper(substr(x,1,1)) || lower(substr(x,2))`), which produced
`"Ana garcia"` instead of `"Ana Garcia"` — correct on the *first* word
only, wrong on every word after a space. This was caught by actually
running the pipeline and inspecting the output, not by reading the
code and assuming it was right — see `README.md`'s "verified output"
section for the real before/after. **This is the exact reason macros
matter operationally, not just stylistically**: the bug lived in
exactly one place (the macro body), and fixing it there instantly
corrected every model that called it — `stg_customers` needed zero
changes once the macro itself was fixed.

## `{% if %}` — conditional compilation, not runtime logic

```sql
{% if is_incremental() %}
    and o.order_date > (select max(order_date) from {{ this }})
{% endif %}
```
This is not a runtime `IF` statement — dbt evaluates `is_incremental()`
**at compile time**, before any SQL is sent to the warehouse. On a
model's first run (table doesn't exist yet), this entire block is
simply omitted from the compiled SQL. On a later run, it's included.
The warehouse never sees an `IF` — it only ever sees the final,
already-decided SQL. This is a genuinely different execution model
from application code, worth stating explicitly since it trips up
people coming from a general-purpose programming background.

## Built-in Jinja variables worth knowing

- **`{{ this }}`** — refers to the current model's own resolved table
  name. Only meaningful inside logic that references the model's
  *own* previously-built state (the incremental watermark pattern
  above is the standard use case).
- **`{{ target }}`** — information about the current run's target
  (environment name, schema, database) — used for environment-
  conditional logic, e.g. behaving differently in `dev` vs `prod`.
- **`{{ var(...) }}`** — reads a variable passed at run time
  (`dbt run --vars '{"my_var": "value"}'`) or defined in
  `dbt_project.yml` — used for run-time configurable behavior without
  hard-coding values into the SQL.

## When macros are overkill

Not every two-line SQL snippet needs to become a macro. The judgment
call: if logic is used in **exactly one place** and unlikely to be
reused, inlining it is simpler and more readable than introducing an
indirection someone has to jump to a separate file to understand. This
project's `title_case()` macro earns its existence because it's called
**twice** in one model already, with an obvious path to more callers
as the project grows — that reuse is what justifies the abstraction.
