# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-06-06

### Added

- **Custom error page** modeled as a first-class surface. Built-in Auth0-shaped defaults for the tenant
  error page's variable contract (`error`, `error_description`, `tracking`, `connection`, `client_id`,
  `lang`) so an error template renders a real scenario without a fixture; a brand-neutral bundled
  `error_page.liquid` that switches copy per code via `{% case error %}` and escapes every request-derived
  variable; a new `error_page` kind (auto-detected from an `error_page`/`error` filename, or set via
  `_meta.kind`) previewed with browser chrome under a new "Páginas de erro" sidebar group. Scenarios are
  switched via the Variáveis editor or per-request overrides (e.g. `?error=too_many_requests`).

## [0.2.0] - 2026-06-06

### Added

- Preview the New Universal Login widget logo from page-template branding context: the injected widget
  resolves `organization.branding.logo_url` (org-context login) → `branding.logo_url` (tenant) → the
  monogram fallback, riding the existing merge order (defaults < fixture < override) with no new env var or
  param. `branding` / `organization.branding` were added to the built-in default context (brand-neutral,
  empty logo) so the lookup is defined under `STRICT_VARIABLES` and surfaces in the Variáveis editor; the
  default preview (empty logo → monogram) is unchanged.

## [0.1.0] - 2026-06-05

### Added

- Local preview server for Auth0 Liquid templates (email + New Universal Login page),
  rendered with Shopify Liquid via the `liquid` gem.
- Generic template discovery from `TEMPLATES_DIR` (default `/templates`), with hot reload:
  templates and `_fixtures/*.json` are read fresh from disk on every request.
- Variable resolution with built-in Auth0-shaped defaults < `_fixtures/<name>.json` < per-request
  overrides (scalar query params and deep-merging POSTed JSON).
- `auth0:head` / `auth0:widget` token substitution (both `{%- … -%}` and `{% … %}` forms) so a
  `.liquid` stays uploadable to Auth0 verbatim; the injected head/widget is a brand-neutral monochrome
  approximation sized to fit the bundled split-screen Universal Login page.
- HTTP routes: the previewer (`GET /`), `GET`/`POST /render/<name>` (composed email HTML),
  `?_raw=1` (rendered plain text), `?source=1` (composed, token-intact uploadable source),
  `?theme=<quiet|editorial|structured>`, and `GET`/`POST /api/meta/<name>` (subject + sender JSON
  for the email-client chrome).
- `ALLOWED_HOSTS` env var (Django-style, comma-separated; `*` for any) to permit previewing over a
  LAN address or a tunnel without hitting Sinatra's `403 Host not permitted`.
- Bundled brand-neutral `examples/` set (11 templates) so the image runs standalone: 10 monochrome
  **pt-BR** identity emails authored as theme-agnostic fragments (OTP rendered as per-character cells,
  crafted inline SVG icons + monogram, no external images) plus a split-screen pt-BR Universal Login page
  (dark brand panel + widget slot), shown with browser chrome in the previewer.
- Three switchable email themes (Quiet · Editorial · Structured) composed around each fragment at render
  time via `EmailTheme`; full-document templates are auto-detected and rendered unthemed/verbatim.
- A previewer UI (`lib/ui/index.html.erb`, vanilla JS, no framework): grouped collapsible sidebar +
  search, device/orientation toggles, theme switch, Prévia ↔ Liquid source view with copy, and a live
  Variáveis editor — all powered by the Ruby renderer.
- `_meta.group` (previewer sidebar section) and `_meta.subject` (Liquid subject line) fixture conventions.
- Docker Compose dev workflow (webserver, tests, lint-formatter), Minitest suite, RuboCop config,
  and a multi-arch publish workflow for `tinuvi/auth0-liquid-renderer`.
