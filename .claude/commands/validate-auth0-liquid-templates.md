---
description: Validate Auth0 Liquid templates (email templates + the New Universal Login page) against Auth0's real requirements and variable model. Project-agnostic — you supply where the templates live.
argument-hint: [path/glob to the .liquid templates, or a note on where they live]
---

Validate Auth0 Liquid templates in this project and report, per template, whether it will work when uploaded to Auth0. Cover both kinds: **email templates** and the **New Universal Login (ULP) page template**.

This command is agnostic to repo layout. The operator tells you where the templates are via `$ARGUMENTS` (a path, a glob, or a description). If `$ARGUMENTS` is empty, ask once for the location and which kinds to check, then proceed. Read the actual files — do not assume a structure.

Goal is a **verdict, not a rewrite**. Don't edit templates unless explicitly asked; surface findings and fixes.

## Method

1. **Discover & classify.** Find the `.liquid` files the operator pointed at. Classify each as ULP (contains `auth0:head`/`auth0:widget`, or is a full login page) or email. For emails, map the file to an Auth0 template name (see below). Note whether each file is a complete HTML document or a bare body fragment — this decides what actually gets uploaded.
2. **Check against the rules** for its kind (sections below).
3. **Resolve every variable** the template references against Auth0's supplied context. This is the crux — see the heuristic.
4. **Report** with a per-template verdict.

## Universal Login page template — hard rules

Auth0 rejects or mis-renders the page unless all hold:

- Contains `{%- auth0:head -%}` inside `<head>` and `{%- auth0:widget -%}` inside `<body>`. The trimmed form is canonical; the non-trimmed `{% auth0:head %}` / `{% auth0:widget %}` forms are also accepted. **Both tokens are mandatory** — the Management API rejects a template missing either.
- It is a **full HTML document** (`<html>`, `<head>`, `<body>`).
- It does **not** target Auth0's internal CSS class names (they are regenerated on every Auth0 build) and does **not** depend on the widget's internal HTML structure. Custom CSS must scope to the template's own classes.
- Every Liquid variable is one Auth0 actually supplies: `application.{name,id,logo_url,metadata}`, `organization.{id,name,display_name,metadata,branding.*}`, `branding.{logo_url,colors.*}`, `tenant.{friendly_name,support_email,support_url,enabled_locales}`, `locale`, `dir`, `prompt.{name,screen.name,screen.texts}`, `custom_domain.*`, `correlation_id`, `state`. `user.*` is only on post-authentication screens.
- Remember **one template renders every prompt** (login, MFA, password reset, logout, consent, error…). Flag login-only copy hardcoded into the shared chrome — it renders, but reads wrong elsewhere.

Tenant prerequisites (not template defects, but report them): a **Custom Domain is required** for custom page templates to take effect, and the template is set **only via the Management API** (`auth0_branding` in Terraform).

## Email templates — hard rules

- The template name must be one Auth0 recognizes: `verify_email`, `verify_email_by_code`, `reset_email`, `reset_email_by_code`, `welcome_email`, `blocked_account`, `stolen_credentials`, `enrollment_email`, `mfa_oob_code`, `user_invitation`, `async_approval` (legacy: `change_password`, `password_reset`). Confirm the file maps cleanly to one.
- Body must be **HTML** (Auth0 does not send plain-text emails).
- **Common variables** (all templates): `application.{name,clientID,callback_domain,client_metadata}`, `user.{email,email_verified,name,nickname,given_name,family_name,picture,app_metadata,user_metadata}`, `organization.*` (when in org context), `tenant` / `friendly_name`, `request_language`, `connection.name` (absent in MFA enrollment), `custom_domain.*`.
- **Template-specific link/code variables** — verify the right one is used:
  - `url`: `verify_email`, `reset_email`, `blocked_account`, `stolen_credentials`, `user_invitation`
  - `code`: `verify_email_by_code`, `reset_email_by_code`, `mfa_oob_code`
  - `link`: `enrollment_email`
  - `inviter.name`, `roles.{id,name,description}`: `user_invitation`
  - `user.source_ip`, `user.city`, `user.country`: `blocked_account`
- `support_url` is **not** Auth0-supplied. If a template uses it, it must be guarded (`{% if support_url %}`) or hardcoded — otherwise it renders empty.
- **Fragment vs. full document:** if the on-disk file is a body fragment styled by an external wrapper/theme, the uploadable artifact is the *composed* output, not the raw file. Validate the thing that actually gets uploaded, and warn if someone might upload the bare fragment (it arrives unstyled).

## The heuristic that matters most

**Auth0's published variable table is not exhaustive — absence from it does not mean a variable is unavailable.** For example, `url` works in `stolen_credentials` (breach emails contain a password-reset link) and in `user_invitation` (the accept link), yet neither is listed in the docs' per-template table. So:

- Never declare a variable "broken" on a single doc omission.
- When availability is ambiguous, corroborate across **multiple** authoritative sources before concluding, and say so in the verdict. Prefer official + provider + real-behavior evidence over one page.

## Authoritative sources

Auth0 docs render as Markdown if you **append `.md`** to the URL — fetch that, and follow internal links with `.md` too:

- ULP templates: `https://auth0.com/docs/customize/login-pages/universal-login/customize-templates.md`
- Email overview: `https://auth0.com/docs/customize/email/email-templates.md`
- Email supported Liquid syntax (per-template variables): `https://auth0.com/docs/customize/email/email-templates/supported-liquid-syntax.md`
- Customize email templates (redirect / `result_url`): `https://auth0.com/docs/customize/email/email-templates/customize-email-templates.md`
- Breached password behavior: `https://auth0.com/docs/secure/attack-protection/breached-password-detection.md`

GitHub — use the **octocode-mcp** tools for all GitHub work (you have the full set available; pick whichever fit — view structure, read files, search code, inspect issues/PRs):

- `auth0/terraform-provider-auth0` — `docs/resources/email_template.md` is the canonical template-name enum and documents `result_url`, `url_lifetime_in_seconds`, `include_email_in_redirect` (the last applies only to `reset_email`/`verify_email`). Its **issues and PRs** are the best source for real runtime behavior the docs omit.
- `auth0/auth0-python` and `pulumi/pulumi-auth0` — corroborate the template-name enum.
- `auth0/auth0-deploy-cli` — example email template + config file layout.

When the docs and the provider still leave a variable ambiguous, check the Auth0 **Support Center** (`support.auth0.com`) and **Community** (`community.auth0.com`) for the specific template's behavior. (Old `community.auth0.com/t/...` links often 301 to a `support.auth0.com` article — follow the redirect.)

## Report

For each template, a verdict line: **VALID** / **RISK (verify)** / **INVALID**, plus the specific rule it passed or failed, the evidence (cite the source), and the fix if any. Then separate three buckets so the operator can act:

1. **Template-validity** issues (will it render / will Auth0 accept it).
2. **Tenant prerequisites** (e.g. Custom Domain, Management-API-only upload) — not defects, but blockers to going live.
3. **Email-client rendering** caveats (e.g. `<style>` in `<head>` + flexbox + CSS custom properties degrade in Outlook's Word engine) — robustness tradeoffs, not Auth0 problems.

End with a one-line overall conclusion and, for any RISK item, the single concrete check that would settle it (often: send a real test email from the tenant, or render the upload artifact and inspect the link/`href`).
