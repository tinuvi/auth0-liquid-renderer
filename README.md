# Auth0 Liquid Renderer

A small, local preview server for **Auth0 Liquid templates** — both **email templates** and the
**New Universal Login page template**. Point it at a folder of `.liquid` files, open
`http://localhost:9292/`, and you get a previewer: a collapsible sidebar grouped by kind, device and
orientation toggles, a live variable editor, and a Prévia ↔ Liquid source switch.

It never talks to Auth0 and needs no credentials — it is a preview tool. A file that renders here is meant
to be uploadable to Auth0 **verbatim** (e.g. via the Terraform `auth0_email_template` /
`auth0_branding` resources). Full-document templates (the Universal Login page, or your own standalone
`.liquid` files) are your source of truth and preview input unchanged. The bundled identity emails are
authored as theme-agnostic **fragments** composed with a theme at render time — their uploadable artifact
is "fragment + chosen theme", exported via `?source=1&theme=…` (see
[Bundled identity emails & themes](#bundled-identity-emails--themes)).

Stack: Ruby 4.0 · [Liquid](https://github.com/Shopify/liquid) · [Sinatra](https://github.com/sinatra/sinatra)
· Puma. Distributed as the multi-arch image `tinuvi/auth0-liquid-renderer`.

## Quick start

Run the bundled sample templates:

```bash
docker run --rm -p 9292:9292 tinuvi/auth0-liquid-renderer
# open http://localhost:9292/
```

Preview **your own** templates by mounting a folder at `/templates`:

```bash
docker run --rm -p 9292:9292 -v "$PWD/my_templates:/templates:ro" tinuvi/auth0-liquid-renderer
```

Editing a `.liquid` file and refreshing the browser shows the change immediately — files are read fresh on
every request, so no restart is needed.

## Template folder conventions

Inside the mounted directory (`TEMPLATES_DIR`, default `/templates`):

```
my_templates/
  welcome_email.liquid            # a template; its name is the basename ("welcome_email")
  universal_login.liquid          # the ULP page template
  _fixtures/
    welcome_email.json            # default render variables for welcome_email.liquid (optional)
    universal_login.json
```

- Each top-level `*.liquid` file is a template. Files under `_fixtures/` and any non-`.liquid` file are ignored.
- `_fixtures/<name>.json` supplies the default variables used when rendering `<name>.liquid`.
- A fixture may include an optional `"_meta"` object (stripped before rendering) to set the index entry:
  ```json
  { "_meta": { "title": "Boas-vindas", "description": "Enviado após verificar o e-mail",
               "kind": "email", "group": "Onboarding", "subject": "Bem-vindo(a) à {{ application.name }}" },
    "user": { "email": "user@example.com" }, "application": { "name": "Acme" } }
  ```
  - `group` sets the previewer sidebar section (e.g. `Onboarding` · `Acesso à conta` · `Segurança`; anything
    else falls under `Outros`). `subject` is a Liquid string rendered for the email-client chrome.

### Variable resolution (later wins)

1. Built-in Auth0-shaped defaults baked into the image.
2. `_fixtures/<name>.json` (minus `_meta`).
3. Per-request overrides (query string or POSTed JSON — see routes below).

> **Note on `support_url`:** this is **not** a built-in Auth0 email variable. The bundled
> fixtures define it for previews, but if your templates reference it they must hardcode or
> derive it for the real Auth0 upload — Auth0 will not supply it.

## Routes

| Route | Purpose |
|---|---|
| `GET /` | The previewer: grouped sidebar + search, device/orientation toggles, theme switch, source view, and a live variable editor. |
| `GET /render/<name>` | Render `<name>.liquid` into the composed email HTML (the previewer iframe body). Scalar query params override top-level context keys (e.g. `?preferredLanguage=en-US`). |
| `POST /render/<name>` | Render with a JSON body that deep-overrides the context (arbitrary nested variables). |
| `GET /render/<name>?theme=<quiet\|editorial\|structured>` | Compose a body fragment with the given theme (default `quiet`; ignored for full-document templates). Combines with the rows below. |
| `GET /render/<name>?_raw=1` | Return the **rendered** output as `text/plain`. |
| `GET /render/<name>?source=1` | Return the **composed, token-intact** document as `text/plain` — the per-theme `.liquid` to upload to Auth0. |
| `GET\|POST /api/meta/<name>` | JSON `{subject, from_name, from_addr, to}` for the email-client chrome (subject is Liquid; sender derived from `application.name`). |

An unknown template returns `404`; a Liquid error returns a visible error page, never a blank `200`.

## Bundled identity emails & themes

The bundled samples are 10 brand-neutral, monochrome **pt-BR** identity emails (`examples/*.liquid`)
carrying real Auth0 Liquid tokens — OTP codes render as per-character cells via a genuine
`{% assign … | split: "" %}` + `{% for %}` loop, and every type has a crafted inline SVG icon and a
reskinnable monogram (no external images).

Each email is authored as a theme-agnostic **body fragment** (no `<html>`/`<head>` of its own). At render
time the server wraps it with one of three monochrome **themes** to form a complete document:

- **Quiet** — centered, minimal, sans-serif, round icon chip, pill buttons (default).
- **Editorial** — left-aligned, serif headline, a 3px top rule, square edges.
- **Structured** — bordered card with a header tag chip and a dark alert band.

A source that is already a full document (the Universal Login page, or any standalone `.liquid` you mount)
is detected and rendered **as-is, unthemed** — so generic templates keep working verbatim.

Because the on-disk email is a fragment, the verbatim-uploadable artifact is "fragment + chosen theme".
Export it (tokens intact) with `?source=1`:

```bash
curl "http://localhost:9292/render/welcome_email?theme=structured&source=1"
```

The previewer's **Liquid** view shows exactly this, and **Copiar** copies it.

## Universal Login templates

Auth0's page template requires the literal tokens `{%- auth0:head -%}` and `{%- auth0:widget -%}` in the
body. This renderer accepts those exact tokens (and the non-trimmed `{% auth0:head %}` / `{% auth0:widget %}`
forms) and substitutes representative head + login-widget HTML so you can preview the page layout.

> The injected head/widget HTML is a **visual approximation** for layout preview only — it will not match
> Auth0 pixel-for-pixel and drifts across Auth0 UI versions. Pin the approximated ULP CSS with
> `AUTH0_ULP_CDN_VERSION`.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `TEMPLATES_DIR` | `/templates` | Directory scanned for `*.liquid` + `_fixtures/`. Falls back to the bundled samples if empty/missing. |
| `PORT` | `9292` | Listen port. |
| `BIND` | `0.0.0.0` | Bind address. |
| `STRICT_VARIABLES` | off | When set, render in Liquid strict-variables mode so undefined references error (catches typos). |
| `AUTH0_ULP_CDN_VERSION` | `1.59.25` | Version of the Universal Login CSS used in the `auth0:head` approximation. |
| `ALLOWED_HOSTS` | _(localhost only)_ | Extra hostnames allowed in the `Host`/`X-Forwarded-Host` header, for previewing over a LAN address or a tunnel. See below. |

### Previewing over a LAN address or a tunnel (`ALLOWED_HOSTS`)

The server only answers requests whose host is permitted (localhost by default) and otherwise returns
`403 Host not permitted`. To preview from another device — your phone over the LAN, or through a tunnel like
ngrok/Cloudflare — list the extra hostnames in `ALLOWED_HOSTS` (comma-separated, Django-style):

```bash
docker run --rm -p 9292:9292 \
  -e ALLOWED_HOSTS="abcd-1-2-3-4.ngrok-free.app" \
  tinuvi/auth0-liquid-renderer
```

- Comma-separate multiple hosts: `ALLOWED_HOSTS="host-a.example.com,host-b.example.com"`.
- A leading dot matches subdomains: `.ngrok-free.app` permits any `*.ngrok-free.app` host.
- `ALLOWED_HOSTS="*"` permits any host (handy for a quick demo; avoid leaving it on).
- `localhost` and loopback addresses stay permitted regardless, so you can't lock yourself out.

## Using it from an infrastructure repo

Add a Compose service that mounts your templates folder (this image is the renderer; your repo carries only
the `.liquid` files and their fixtures):

```yaml
services:
  auth0-templates:
    image: tinuvi/auth0-liquid-renderer:latest
    volumes:
      - ./path/to/auth0_templates:/templates:ro
    ports:
      - "9292:9292"
```

```bash
docker compose up --remove-orphans auth0-templates   # http://localhost:9292/
```

## License

[MIT](./LICENSE).
