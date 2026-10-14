# ORM and security

Use for model, field, access-control, configuration and query changes. These
details were checked against the baseline in [source map](source-map.md);
confirm the affected APIs in the project's current Odoo 20 build.

## Access declarations

Odoo 20 declares access through `ir.access`, with `model_id`, `group_id`,
`operation` and `domain`. The operation uses CRUD letters: read `r`, update `u`,
create `c`, delete `d`, or their supported combinations. Do not port old
`ir.model.access` and `ir.rule` declarations by simply renaming fields.

Applicable records with a group grant permissions; records without a group
restrict them. The resulting domain combines permissions with OR and
restrictions with AND. An unrestricted group grant can therefore defeat a
scoped group grant. Review all applicable declarations for the operation.
[Access model](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/addons/base/models/ir_access.py),
[composition](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/orm/models.py#L3601-L3647).

Use `check_access()` or `has_access()` with the supported operation names at
the appropriate recordset. An empty model recordset supports a model-level
check; it does not prove access to a particular record. Check the receiving
user's access to actual records before an elevated operation.

When authorization ties several conditions to one related record, express that
correlation explicitly. For example, a membership's user and role must match
the same membership. Independent dotted-path conditions may match different
related records. Inspect the current `Domain` and relational `any` semantics.
[Domain implementation](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/orm/domains.py).

## Models and fields

Read the ORM method before changing its signature or return-value expectations.
Preserve recordset semantics in methods that can receive multiple records.
Prefer framework batching and prefetching over repeated searches inside loops.
Inspect the actual aggregation API before copying a `read_group` example.

Declare database constraints with `models.Constraint`; `_sql_constraints`
is unsupported in the inspected build. Check existing constraint names and
populated values before changing a declaration.
[Table objects](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/orm/table_objects.py),
[model registration](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/orm/model_classes.py).

Verify supported field parameters and decorator behavior in the current
`odoo/orm` and `odoo/api` implementations. Related-record ordering, inactive
records, company context and computed-field dependencies can change the observed
result without a SQL query being wrong.

Raw SQL bypasses normal ORM access, recomputation and cache management. Use
parameterized framework SQL helpers where SQL is justified, and inspect the
required flush, invalidation and `modified()` behavior for the affected fields.

## Configuration

The inspected `ir.config_parameter` has typed getters and setters. Use
`get_str` and `set_str` for strings; inspect the matching typed methods for other
values. Preserve the distinction between missing, empty and false values and
check who can read or change the parameter. Avoid returning secrets through a
general configuration endpoint.
[Configuration implementation](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/addons/base/models/ir_config_parameter.py).
