{% macro title_case(column_name) %}
    {#-
        Reusable text-standardization logic. Written once here, called
        from every staging model that needs it (stg_customers uses it
        twice: on first_name and on country) instead of copy-pasting
        the same logic into every model that needs casing cleaned up.
        This is the entire value proposition of a dbt macro: DRY
        logic, defined once, usable anywhere via Jinja's {{ }}
        templating -- see docs/06-macros-and-jinja.md for the full
        explanation of why this beats copy-pasted SQL.

        Also demonstrates a macro doing more than one thing: trims
        whitespace AND applies proper word-by-word capitalization.
        DuckDB has no built-in initcap(), so this splits on spaces,
        capitalizes each word's first letter via list_transform, and
        rejoins -- correctly turning "sophie dubois" into
        "Sophie Dubois" (both words), not just capitalizing the first
        character of the whole string.
    -#}
    array_to_string(
        list_transform(
            string_split(lower(trim({{ column_name }})), ' '),
            word -> upper(word[1:1]) || word[2:]
        ),
        ' '
    )
{% endmacro %}

