# Module data, persistence and testing

Use for installation data, database changes, attachments and framework tests.
The project supplies commands and delivery conventions; this reference supplies
Odoo integration contracts. See [source map](source-map.md) for the inspected build.

## Module registration and data

Check Python imports, manifest dependencies, data load order and asset entries
together. A defined model or controller must be imported through the package;
an XML record referencing another module needs the corresponding dependency.
Keep XML identifiers stable when records should survive upgrades.

CSV loading selects a target model from its filename. Access data for the
inspected build therefore uses `ir.access.csv`, with columns appropriate to
`ir.access`. Check XML/CSV loader behavior, `noupdate` and external-ID ownership
when an update does not alter an existing record.
[Data loader](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/tools/convert.py).

For actions, views, cron and QWeb reports, trace a comparable built-in addon
through its manifest, data records and handler. Inspect the current schema
instead of copying a complete older-version module template.

## Persistence

Use `ir.attachment.raw` for the inspected build's binary content API. Inspect
its binary value type and record linkage rather than assuming a base64 `datas`
interface. An attachment's resource and access policy must match the route
that serves it.
[Attachment implementation](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/addons/base/models/ir_attachment.py).

Model and constraint changes affect existing rows as well as fresh installs.
Establish whether a migration is necessary for stored values, external IDs or
constraints. Use the actual source schema and preserve record identities and
relationships where the product contract requires them. Framework code-conversion
tools provide examples; inspect their output and current API compatibility.
[Official conversion tools](https://github.com/odoo/odoo/tree/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/upgrade_code).

When catching a database error, inspect the savepoint and cursor/cache semantics
before continuing. A failed SQL statement can leave the transaction unusable;
do not hide it and continue ORM writes in the same invalid transaction.
[Cursor/savepoints](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/sql_db.py).

## Framework test boundaries

- `TransactionCase` exercises ORM behavior and access as selected users.
- `HttpCase` exercises authenticated HTTP behavior; fixture creation and the
  authenticated request may run as different principals.
- Hoot and the web test helpers exercise components, services and RPC behavior
  in a browser. Mocked success alone cannot establish actual app bootstrap,
  layout or cross-entry-point behavior.
[Backend test classes](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/tests/common.py),
[web helpers](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/addons/web/static/tests/web_test_helpers.js).

Use explicit test users and company contexts for access checks. Include denied
operations and mixed related-record cases when authorization changes. Account
for ORM caching when asserting values or related-record ordering after writes.

`odoo.http.request` is a proxy outside a request context. Controller unit tests
should patch the module's imported request with a controlled object rather than
letting a mock inspect the live proxy. Check existing test fixtures and framework
reserved attributes before adding similarly named test methods.

Register Python test modules in `tests/__init__.py` and web tests in the supported
test bundle. An empty test selection or skipped wrapper does not verify the
changed behavior. Use the project's existing runner and report the boundary it
actually exercised.
