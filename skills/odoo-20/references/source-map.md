# Odoo 20 source map

Read when identifying the actual framework or researching a topic absent from
the other references. Find the project's image/source pin and read the matching
core and built-in addons. Prefer version-matched official documentation where
available; a moving branch or an adjacent older checkout does not identify the
running build.

## Inspected baseline

On 2026-10-14 the existing runtime reported `20.0-20260926`; its bundled Owl
reported `3.0.0-alpha.49`. Its access model, Owl compatibility layer, config
parameter implementation and table objects matched the files at official commit
[`491e981505d28dfd85edea8ffb67bc8ed00826aa`](https://github.com/odoo/odoo/tree/491e981505d28dfd85edea8ffb67bc8ed00826aa)
by SHA-256. These are dated source checks, not a pin every project must adopt.
Recheck affected contracts when the project's build differs or changes.

In this build `odoo` is a namespace package: `odoo.__file__` can be `None`.
Locate its package through `odoo.__path__` or a concrete submodule; addon paths
in the package can differ from their upstream repository paths.

## Find the implementation

| Topic | Paths in the official Odoo repository |
| --- | --- |
| ORM, fields, recordsets, domains and constraints | `odoo/orm/`, `odoo/api/` |
| Access declarations and combination | `odoo/addons/base/models/ir_access.py`, `odoo/orm/models.py` |
| HTTP routes and dispatchers | `odoo/http/routing_map.py`, `odoo/http/dispatcher.py` |
| Owl and framework compatibility | `addons/web/static/lib/owl/owl.js`, `addons/web/static/src/owl2/` |
| App startup, services and assets | `addons/web/static/src/env.js`, `addons/web/__manifest__.py` |
| Views, actions, cron, configuration and attachments | `odoo/addons/base/models/` |
| XML/CSV loading and upgrade conversion | `odoo/tools/convert.py`, `odoo/upgrade_code/` |
| Database transactions | `odoo/sql_db.py` |
| Backend and browser testing | `odoo/tests/common.py`, `addons/web/static/tests/web_test_helpers.js`, `addons/web/static/lib/hoot/` |
| Mail, activities and tracking | `addons/mail/`, `addons/mail_tracking/` |
| Reports and translation | `odoo/addons/base/models/ir_actions_report.py`, `odoo/tools/translate.py`, comparable built-in addons |

Edition-specific integrations need the corresponding installed sources. The
Community inspection above does not establish Enterprise behavior.
