# Web and HTTP

Use for Owl, assets, controllers and public applications. Verify these contracts
against the current bundle; the inspected baseline is in [source map](source-map.md).

## Bundled Owl

The inspected Odoo 20 build bundles Owl `3.0.0-alpha.49`. Its exports include
`proxy`, `signal` and `useProps`; its old `useState` and `useRef` exports are absent.
Check exports before copying code from an Owl 2 guide.
[Bundled library](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/addons/web/static/lib/owl/owl.js).

- Declare component props through `useProps`. The inspected compatibility layer
  rejects component `static props` and `static defaultProps`.
- Use `proxy` when the component needs a reactive object. Preserve the intended
  object shape and ownership when converting existing state.
- Native refs use `signal.ref()` and are read by calling the ref, rather than
  accessing an Owl 2 ref's `.el`. Match the current template ref binding.
- Qualify component-owned properties and methods with `this.` in templates;
  distinguish them from locally bound template variables.
- Native reactive effects and DOM lifecycle effects have different timing.
  The framework's `useLayoutEffect` can preserve a dependency-based DOM effect;
  inspect its implementation instead of assuming Owl 2 `useEffect` semantics.
[Compatibility layer](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/addons/web/static/src/owl2/owl3_compatibility_layer.js),
[chart/ref example](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/addons/web/static/src/core/utils/chart_hook.js).

## App startup and assets

For an application needing Odoo services and templates, inspect `mountComponent`
in `@web/env`. It creates the environment, waits for plugins and mounts an
application root. Do not reproduce an old `startServices` or
`new App(Component, options)` bootstrap without checking current support.
[Framework bootstrap](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/addons/web/static/src/env.js).

Declare assets in the addon's manifest using current bundle names and actual
paths. A path present in an older Odoo release may no longer exist. Inspect
`addons/web/__manifest__.py` and a comparable built-in addon before adding web
bootstrap, icon fonts or public/kiosk assets.

Check which environment supplies templates, translations and services for a
public application. An authenticated editor's environment is not sufficient
evidence for anonymous rendering. Keep shared components' read-only behavior
explicit and enforce authorization again at their HTTP/ORM boundaries.

## Controllers

Use the current route and dispatcher APIs. The inspected release supports
`type='jsonrpc'` and `type='http'`; verify the payload and response contract for
the selected type. Do not convert an internal JSON-RPC route to JSON-2 merely
because newer external API documentation discusses JSON-2.
[Route contract](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/http/routing_map.py),
[dispatchers](https://github.com/odoo/odoo/blob/491e981505d28dfd85edea8ffb67bc8ed00826aa/odoo/http/dispatcher.py).

Specify authentication and inspect the route's CSRF, HTTP-method and session
behavior. Validate record identifiers and input fields before elevating access.
A valid public token should grant only its intended resource and operations;
check related attachments and child records against the same resource boundary.
Return errors through the selected dispatcher's supported response mechanism.
