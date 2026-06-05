# frozen_string_literal: true

# Substitution pass for Auth0's New Universal Login page-template tokens.
#
# Auth0's page template requires the literal tokens `{%- auth0:head -%}` and
# `{%- auth0:widget -%}` (and the non-trimmed `{% auth0:head %}` / `{% auth0:widget %}`
# forms) in the body. A Liquid tag name cannot contain ":", so these are deliberately
# NOT implemented as a registered Liquid tag (that would force a different syntax and
# break verbatim upload to Auth0). Instead:
#
#   1. swap each token for a unique sentinel BEFORE Liquid parses the source,
#   2. let Liquid render the rest of the template,
#   3. swap the sentinels for representative head + login-widget HTML AFTER render.
#
# Substituting before parse keeps the .liquid file uploadable to Auth0 byte-for-byte
# and stops Liquid from trying to re-process the injected HTML.
#
# The injected HTML is a STATIC VISUAL APPROXIMATION for layout preview only — it will
# not match Auth0 pixel-for-pixel and drifts across Auth0 UI versions. The pinned ULP
# CSS version is configurable via AUTH0_ULP_CDN_VERSION.
module Auth0Ulp
  HEAD_TOKEN   = /\{%-?\s*auth0:head\s*-?%\}/
  WIDGET_TOKEN = /\{%-?\s*auth0:widget\s*-?%\}/

  HEAD_SENTINEL   = "@@AUTH0_HEAD_SENTINEL@@"
  WIDGET_SENTINEL = "@@AUTH0_WIDGET_SENTINEL@@"

  # Matches the class names baked into the static widget approximation below.
  DEFAULT_CDN_VERSION = "1.59.25"

  module_function

  # True when the source carries either ULP token (used to derive a template's kind).
  def tokens?(source)
    HEAD_TOKEN.match?(source) || WIDGET_TOKEN.match?(source)
  end

  # Step 1: tokens -> sentinels (run on the raw source, before Liquid).
  def to_sentinels(source)
    source.gsub(HEAD_TOKEN, HEAD_SENTINEL).gsub(WIDGET_TOKEN, WIDGET_SENTINEL)
  end

  # Step 3: sentinels -> HTML (run on Liquid's output). Block form of gsub so the
  # injected HTML is treated literally (no \0/\1 backreference interpretation).
  def from_sentinels(rendered, cdn_version: DEFAULT_CDN_VERSION)
    head = head_html(cdn_version)
    rendered.gsub(HEAD_SENTINEL) { head }.gsub(WIDGET_SENTINEL) { WIDGET_HTML }
  end

  def head_html(cdn_version = DEFAULT_CDN_VERSION)
    <<~HTML.freeze
      <link rel="stylesheet" href="https://cdn.auth0.com/ulp/react-components/#{cdn_version}/css/main.cdn.min.css">
      <style id="custom-styles-container">
        body { font-family: ulp-font, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        :root { --primary-color: #635dff; --page-background-color: #f5f6fc; }
        .no-js { clip: rect(0 0 0 0); clip-path: inset(50%); height: 1px; overflow: hidden; position: absolute; white-space: nowrap; width: 1px; }
      </style>
    HTML
  end

  # Representative ULP login widget. Static approximation, brand-neutral copy.
  WIDGET_HTML = <<~HTML
    <main class="_widget login">
      <section class="_prompt-box-outer c082bfae4 ca9a51135">
        <div class="ca7765aa4 cc0f204d0">
          <div class="ce37485e0">
            <header class="c88ace156 cbccf638c">
              <div title="" id="custom-prompt-logo" style="background-color:transparent!important;background-position:50%!important;background-repeat:no-repeat!important;background-size:contain!important;height:60px!important;margin:auto!important;padding:0!important;position:static!important;width:auto!important"></div>
              <img class="c804bd434 ca84a5be8" id="prompt-logo-center" src="https://cdn.auth0.com/styleguide/components/1.0.8/media/logos/img/badge.png" alt="">
              <h1 class="c4faf1005 ce61d44fd">Welcome</h1>
              <div class="c87ba88d2 cf51804e0">
                <p class="c312fad3e cff44daea">Log in to continue.</p>
              </div>
            </header>
            <div class="c435f65a3 c5402e124">
              <form method="post" class="cbc9e259c cc7ea13ef">
                <div class="c3e5f2903 c421eb102">
                  <div class="c35e94f61">
                    <div class="_input-wrapper input-wrapper">
                      <div class="c290d0a77 c6502a50e c6ee2841c cc16b291d ce502c880 text">
                        <label class="c262a03d2 c44052fda ce8710345 no-js" for="username">Email address</label>
                        <input class="c44d26365 c96d13227 focus input" inputmode="email" name="username" id="username" type="text" value="" required="" autocomplete="username" autocapitalize="none" spellcheck="false" autofocus="">
                      </div>
                    </div>
                    <div class="_input-wrapper input-wrapper">
                      <div class="c3ffd83c9 c6502a50e c6ee2841c ce502c880 password">
                        <label class="c262a03d2 c44052fda cc486081b no-js" for="password">Password</label>
                        <input class="c1cea3c8c c96d13227 input" name="password" id="password" type="password" required="" autocomplete="current-password" autocapitalize="none" spellcheck="false">
                      </div>
                    </div>
                  </div>
                </div>
                <p class="c70f3cc15 c9c35fad0">
                  <a class="c57d45e67 c7d975faf ce3b88cb1" href="#">Forgot password?</a>
                </p>
                <div class="c83f0a9b3">
                  <button type="submit" name="action" value="default" class="c14aa4d90 c1eb66faa c75cd95bc c7b79bfac ccf4184c6">Continue</button>
                </div>
              </form>
              <div class="_alternate-action ulp-alternate-action">
                <p class="c0bc001fe c312fad3e cff44daea">Don't have an account?
                  <a class="c7d975faf ce3b88cb1" href="#">Sign up</a>
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>
  HTML
end
