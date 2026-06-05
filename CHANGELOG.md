# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-05
### Added
- Local preview server for Auth0 Liquid templates (email + New Universal Login page),
  rendered with Shopify Liquid via the `liquid` gem.
- Generic template discovery from `TEMPLATES_DIR` (default `/templates`), with hot reload:
  templates and `_fixtures/*.json` are read fresh from disk on every request.
- Variable resolution with built-in Auth0-shaped defaults < `_fixtures/<name>.json` < per-request
  overrides (scalar query params and deep-merging POSTed JSON).
- `auth0:head` / `auth0:widget` token substitution (both `{%- … -%}` and `{% … %}` forms) so a
  `.liquid` stays uploadable to Auth0 verbatim; injected head/widget HTML is a visual approximation,
  with the ULP CSS version configurable via `AUTH0_ULP_CDN_VERSION`.
- HTTP routes: index (`GET /`), `GET`/`POST /render/<name>`, and `?_raw=1` plain-text output.
- Bundled brand-neutral `examples/` set (11 templates) so the image runs standalone.
- Docker Compose dev workflow (webserver, tests, lint-formatter), Minitest suite, RuboCop config,
  and a multi-arch publish workflow for `tinuvi/auth0-liquid-renderer`.
