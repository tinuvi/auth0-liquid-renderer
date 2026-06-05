# Auth0 Liquid Renderer

A small, local preview server for **Auth0 Liquid templates** — both **email templates** and the
**New Universal Login page template**. Point it at a folder of `.liquid` files, open
`http://localhost:9292/`, pick a template, optionally tweak the render variables, and see the rendered
HTML in your browser.

It never talks to Auth0 and needs no credentials — it is a preview tool. A file that renders here is meant
to be uploadable to Auth0 **verbatim** (e.g. via the Terraform `auth0_email_template` /
`auth0_branding` resources), so the same `.liquid` file is both your source of truth and your preview input.

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
  { "_meta": { "title": "Welcome Email", "description": "Sent after email verification", "kind": "email" },
    "user": { "email": "user@example.com" }, "application": { "name": "Acme" } }
  ```

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
| `GET /` | Index of every template, grouped by kind, linking to its render page. |
| `GET /render/<name>` | Render `<name>.liquid`. Scalar query params override top-level context keys (e.g. `?preferredLanguage=en-US`). |
| `POST /render/<name>` | Render with a JSON body that deep-overrides the context (arbitrary nested variables). |
| `GET /render/<name>?_raw=1` | Return the rendered output as `text/plain` (view source / copy). |

An unknown template returns `404`; a Liquid error returns a visible error page, never a blank `200`.

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
