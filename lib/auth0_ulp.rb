# frozen_string_literal: true

# Substitution pass for Auth0's New Universal Login page-template tokens.
#
# Auth0's page template requires the literal tokens `{%- auth0:head -%}` and
# `{%- auth0:widget -%}` (and the non-trimmed `{% auth0:head %}` / `{% auth0:widget %}`
# forms) in the body. A Liquid tag name cannot contain ":", so these are deliberately
# NOT implemented as a registered Liquid tag (that would force a different syntax and
# break verbatim upload to Auth0). Instead we string-substitute the tokens for
# representative head + login-widget HTML BEFORE Liquid parses the source.
#
# Substituting on an in-memory copy keeps the .liquid file uploadable to Auth0
# byte-for-byte. The injected widget itself carries Liquid (`{{ application.name }}`,
# an `{% if organization.display_name %}`), so substitution happens BEFORE render so
# those resolve in the same pass — the previewer mirrors `substituteAuth0` from the
# Claude Design prototype. CSS in the injected/page styles uses single `{`/`}`, which
# Liquid ignores (only `{{` / `{%` trigger it).
#
# The injected HTML is a VISUAL APPROXIMATION for layout preview only — a clean
# monochrome login widget that fits the bundled split-screen page. It will not match
# Auth0's real, tenant-specific widget pixel-for-pixel. Its few dynamic bits resolve
# from context: the subtitle (org/app name) and the logo (branding, see WIDGET_HTML).
module Auth0Ulp
  HEAD_TOKEN   = /\{%-?\s*auth0:head\s*-?%\}/
  WIDGET_TOKEN = /\{%-?\s*auth0:widget\s*-?%\}/

  # Reskinnable monogram, matching the email design system (driven by currentColor).
  MONO = '<svg viewBox="0 0 28 28" width="28" height="28" fill="none" aria-hidden="true"><rect x="1.2" y="1.2" width="25.6" height="25.6" rx="7" stroke="currentColor" stroke-width="1.5"/><rect x="9.4" y="9.4" width="9.2" height="9.2" rx="2" transform="rotate(45 14 14)" fill="currentColor"/></svg>'

  ICON_KEY = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="8" cy="15" r="3.3"/><path d="m10.3 12.7 7-7M14.8 8.2l2.2 2.2M16.6 6.4l2 2"/></svg>'
  ICON_MAIL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2.2"/><path d="M3.5 7.2 12 13l8.5-5.8"/></svg>'

  # What `{%- auth0:head -%}` injects in preview: the widget's stylesheet (Auth0
  # serves the real one at runtime; this is a representative monochrome approximation).
  WIDGET_CSS = <<~CSS
    .w-card{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Helvetica Neue",Helvetica,Arial,sans-serif}
    .w-logo{display:flex;align-items:center;justify-content:center;min-height:46px;margin:0 0 22px;color:#15151a}
    .w-logo svg{width:46px;height:46px}.w-logo img{max-width:180px;max-height:52px;object-fit:contain}
    .w-title{font-size:23px;font-weight:700;letter-spacing:-.02em;text-align:center;color:#15151a;margin:0 0 7px}
    .w-sub{font-size:14px;color:#6f6f78;text-align:center;margin:0 0 26px}
    .w-label{font-size:12.5px;font-weight:600;color:#3b3b42;margin:0 0 6px;display:block}
    .w-input{width:100%;border:1px solid #d4d4da;border-radius:9px;padding:12px 13px;font-size:14px;color:#15151a;background:#fff;margin-bottom:15px;font-family:inherit}
    .w-input::placeholder{color:#a6a6ae}
    .w-row{display:flex;justify-content:flex-end;margin:-7px 0 18px}
    .w-link{font-size:12.5px;color:#15151a;text-decoration:none;font-weight:600}
    .w-btn{width:100%;border:0;background:#15151a;color:#fff;border-radius:9px;padding:13px;font-size:15px;font-weight:600;cursor:pointer}
    .w-div{display:flex;align-items:center;gap:12px;margin:22px 0;color:#a6a6ae;font-size:12px}
    .w-div::before,.w-div::after{content:"";flex:1;height:1px;background:#e7e7ec}
    .w-socials{display:flex;flex-direction:column;gap:10px}
    .w-soc{display:flex;align-items:center;justify-content:center;gap:10px;border:1px solid #d4d4da;border-radius:9px;padding:11px;font-size:14px;font-weight:600;color:#3b3b42;background:#fff;cursor:pointer;text-decoration:none}
    .w-soc svg{width:18px;height:18px;color:#56565e}
    .w-signup{text-align:center;font-size:13px;color:#6f6f78;margin-top:24px}
    .w-signup a{color:#15151a;font-weight:600;text-decoration:none}
  CSS

  HEAD_HTML = %(<style id="auth0-head-approx">#{WIDGET_CSS}</style>).freeze

  # What `{%- auth0:widget -%}` injects in preview. Carries Liquid (resolved in the
  # same render pass) so the subtitle reflects the org/app name and the logo reflects
  # branding. The real widget logo comes from tenant/org branding the renderer never
  # sees, so it is sourced from context here, mirroring Auth0's precedence: an
  # organization-branding logo overrides the tenant `branding.logo_url`. Both are real
  # New-Universal-Login page-template variables; supply either via fixture/override to
  # preview a logo-bearing widget. Empty (the default) falls back to the monogram.
  # `!= blank` is required because "" is TRUTHY in Liquid; `escape` guards the URL going
  # into the attribute (Liquid does not auto-escape).
  WIDGET_HTML = <<~HTML.freeze
    <div class="w-card">
    {%- assign w_logo = organization.branding.logo_url | default: branding.logo_url -%}
    <div class="w-logo">{% if w_logo != blank %}<img class="w-logo-img" src="{{ w_logo | escape }}" alt="{{ application.name | escape }}">{% else %}#{MONO}{% endif %}</div>
    <h1 class="w-title">Bem-vindo de volta</h1>
    <p class="w-sub">Entre na sua conta {% if organization.display_name %}{{ organization.display_name }}{% else %}{{ application.name }}{% endif %}</p>
    <label class="w-label">E-mail</label>
    <input class="w-input" type="email" placeholder="voce@empresa.com">
    <label class="w-label">Senha</label>
    <input class="w-input" type="password" placeholder="••••••••">
    <div class="w-row"><a class="w-link" href="#">Esqueceu a senha?</a></div>
    <button class="w-btn">Continuar</button>
    <div class="w-div">ou</div>
    <div class="w-socials">
    <a class="w-soc" href="#">#{ICON_KEY} Entrar com SSO corporativo</a>
    <a class="w-soc" href="#">#{ICON_MAIL} Entrar com link mágico</a>
    </div>
    <p class="w-signup">Não tem uma conta? <a href="#">Cadastre-se</a></p>
    </div>
  HTML

  module_function

  # True when the source carries either ULP token (used to derive a template's kind).
  def tokens?(source)
    HEAD_TOKEN.match?(source) || WIDGET_TOKEN.match?(source)
  end

  # tokens -> approximation HTML, on the raw source, BEFORE Liquid parses it. Block
  # form of gsub so the injected HTML is treated literally (no backreference interpolation).
  def substitute(source)
    source.gsub(HEAD_TOKEN) { HEAD_HTML }.gsub(WIDGET_TOKEN) { WIDGET_HTML }
  end
end
