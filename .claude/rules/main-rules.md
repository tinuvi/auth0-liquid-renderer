# SDLC rules

Follow these end-to-end on every change. Run everything through Docker Compose — no host Ruby.

## Dependencies

- Keep runtime gems to `liquid`, `sinatra`, `puma`; dev/test gems to `minitest`, `rubocop`, `rake`. Do not add a gem where the Ruby standard library does the job.
- After changing `Gemfile`, regenerate the lockfile and rebuild the images:
    ```bash
    docker compose run --rm --remove-orphans integration-tests bundle install
    docker compose build integration-tests lint-formatter webserver
    ```
    Bump a single gem with `... integration-tests bundle update <gem>`.

## Code style

- Write a test for every implementation change. No exception for "trivial" fixes.
- Keep the core renderer (`lib/renderer.rb`) free of HTTP: take a template name plus overrides, return a String. Put routing only in `lib/app.rb`.
- Let RuboCop format the code; obey `.rubocop.yml` and do not hand-style around it.
- Use the stdlib `Logger` if logging is needed; do not add a logging gem.
- Keep `examples/` templates brand-neutral ("Acme"). Never put real branding here.
- Accept Auth0's literal `{%- auth0:head -%}` / `{%- auth0:widget -%}` tokens (and the non-trimmed forms) so a `.liquid` file stays uploadable to Auth0 verbatim.

## Testing

- Run the full suite before declaring a change complete:
    ```bash
    docker compose run --rm --remove-orphans integration-tests
    ```
- Run one file: `... integration-tests bundle exec rake test TEST=test/renderer_test.rb`.
- Run one method: append `TESTOPTS="-n /welcome/"` to the command above.
- Check rendering by eye at `http://localhost:9292/`:
    ```bash
    docker compose up --remove-orphans webserver
    ```
- Drive the Sinatra app in tests via `Rack::MockRequest`; do not add `rack-test`. There is no coverage tooling.

## Lint & format

- Run after the implementation is complete (formats in place, then lint-gates):
    ```bash
    docker compose run --rm --remove-orphans lint-formatter
    ```
- In CI, lint check-only (`rubocop` without `--autocorrect-all`) so the job fails on offenses instead of rewriting files.

## Documentation

- Update `README.md` when env vars (`TEMPLATES_DIR`, `PORT`, `BIND`, `STRICT_VARIABLES`, `AUTH0_ULP_CDN_VERSION`), filesystem conventions, HTTP routes, or the consumer compose snippet change.
- Do not create new top-level `*.md` docs unless explicitly asked.

## Commits

- Use Conventional Commits.

## Deployment

- Release by pushing an annotated `vX.Y.Z` tag; `.github/workflows/publish.yml` builds the multi-arch (`linux/amd64` + `linux/arm64`) image and pushes `tinuvi/auth0-liquid-renderer:<version>` and `:latest`.
- Derive the version from the git tag; do not hardcode it anywhere else.
