---
name: odoo-20
description: Develop, review, or diagnose Odoo 20 addons using its ORM, access controls, HTTP controllers, Owl components, assets, and testing APIs. Use with an Odoo 20 codebase; verify framework APIs against the project's actual build.
---

# Odoo 20

Supply Odoo 20 framework knowledge. The project supplies business terminology,
runtime commands and deployment details; Matt Pocock skills supply the
development workflow.

## Match the framework

Identify the actual Odoo release, source or image pin and installed edition.
The addon's manifest version alone does not identify its framework build.
Use that build's core and built-in addons as API authority; an adjacent checkout
or documentation for another version may describe different behavior.

Read comparable built-in addons and the relevant project ADRs. Verify moving
Odoo 20 APIs against the current source before changing them. The dated
[source map](references/source-map.md) identifies the inspected baseline and
where to find authoritative implementations.

## Load the relevant knowledge

| Change | Reference |
| --- | --- |
| Models, fields, access domains, configuration or ORM performance | [ORM and security](references/orm-security.md) |
| Owl components, web assets, HTTP endpoints or public rendering | [Web and HTTP](references/web-http.md) |
| Module data, schema changes, attachments or framework tests | [Data and testing](references/data-testing.md) |

Read only the references needed for the affected boundary. For reports, actions,
cron, mail integrations or translations, use the source map to find current
framework examples instead of inventing APIs from older-version memory.

## Keep integration correct

- Evaluate access as the intended user. UI visibility and `sudo()` do not
  establish permission; check received identifiers and their ownership.
- Odoo 20 uses `ir.access` permissions and restrictions. Review how grants
  combine before adding an unrestricted grant alongside scoped access.
- Verify ORM operations on recordsets, company context and cache state.
  Direct SQL bypasses framework behavior unless those responsibilities are
  handled explicitly.
- Match the bundled Owl version and web bootstrap. Verify both authenticated
  and public entry points when a component or endpoint serves both.
- Keep module loading, asset registration and populated-database upgrades
  consistent with the current framework and project.
- Choose framework test types for the boundary being changed. Keep test users
  and request authentication explicit so a superuser fixture does not hide an
  access error.
