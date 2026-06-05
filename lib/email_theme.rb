# frozen_string_literal: true

# Theme composition for the bundled identity emails.
#
# The emails are authored as theme-agnostic BODY FRAGMENTS (semantic markup +
# inline SVGs + real Liquid tokens). A fragment is not a complete HTML document on
# its own; this module supplies the missing <head>/<style> chrome. One shared BASE
# stylesheet plus a per-theme stylesheet (Quiet / Editorial / Structured) reskin
# every email at once, mirroring the design prototype's `buildDoc(theme, body)`.
#
# This parallels Auth0Ulp: a pure string transform around Liquid. `compose_source`
# wraps a fragment into a full document BEFORE Liquid runs; a source that is ALREADY
# a full document (the Universal Login page, or any standalone .liquid a user mounts)
# is passed through untouched, so those keep rendering verbatim and unthemed.
#
# Because the on-disk file is a fragment, the verbatim-uploadable artifact is
# "fragment + chosen theme": the composed, token-intact document returned by
# `compose_source` (exposed over HTTP as /render/<name>?theme=...&source=1).
module EmailTheme
  DEFAULT_THEME = "quiet"
  THEME_ORDER = %w[quiet editorial structured].freeze

  # Design tokens shared by every theme (the prototype's `TOKENS`).
  TOKENS = <<~CSS
    :root{
    --ink-900:#15151a;--ink-800:#26262c;--ink-700:#3b3b42;--ink-600:#56565e;
    --ink-500:#6f6f78;--ink-400:#8d8d96;--ink-300:#d4d4da;--ink-200:#e7e7ec;
    --ink-100:#f4f4f6;--ink-50:#fafafb;--paper:#ffffff;--canvas:#ebebed;
    --mono:ui-monospace,"SF Mono",Menlo,Consolas,"Liberation Mono",monospace;
    --sans:-apple-system,BlinkMacSystemFont,"Segoe UI","Helvetica Neue",Helvetica,Arial,sans-serif;
    --serif:Georgia,"Times New Roman",serif;
    }
  CSS

  # Skeleton shared across themes: layout reset, OTP cells, metadata grid, fallback
  # link, hidden preheader, responsive cell sizing.
  BASE = (TOKENS + <<~CSS).freeze
    *{box-sizing:border-box}
    body{margin:0;background:var(--canvas);-webkit-font-smoothing:antialiased;text-size-adjust:100%}
    .eml-outer{width:100%;background:var(--canvas);padding:40px 16px}
    .eml-card{max-width:var(--maxw,520px);margin:0 auto;background:var(--paper);color:var(--ink-700)}
    a{color:inherit}
    p{margin:0}
    .eml-icon svg{display:block}
    .eml-code{display:flex;flex-wrap:wrap;gap:6px;align-items:center}
    .eml-cell{font-family:var(--mono);font-weight:700;font-size:20px;color:var(--ink-900);background:var(--ink-100);border:1px solid var(--ink-200);width:40px;height:50px;display:flex;align-items:center;justify-content:center;border-radius:8px}
    .eml-dash{font-family:var(--mono);color:var(--ink-300);font-size:20px;padding:0 1px}
    .eml-meta{border:1px solid var(--ink-200);border-radius:10px;overflow:hidden}
    .eml-meta-row{display:flex;justify-content:space-between;gap:16px;padding:11px 16px;border-top:1px solid var(--ink-100);font-size:13.5px}
    .eml-meta-row:first-child{border-top:0}
    .eml-meta-k{color:var(--ink-500)}
    .eml-meta-v{color:var(--ink-900);font-weight:600;font-family:var(--mono);font-size:12.5px;text-align:right}
    .eml-fallback{font-family:var(--mono);font-size:12px;color:var(--ink-500);word-break:break-all;background:var(--ink-50);border:1px solid var(--ink-200);border-radius:8px;padding:12px 14px;line-height:1.6}
    .eml-foot p{margin:0 0 6px}.eml-foot p:last-child{margin:0}
    .eml-pre{display:none!important;visibility:hidden;opacity:0;height:0;width:0;max-height:0;overflow:hidden;mso-hide:all}
    .eml-btn{cursor:pointer}
    @media (max-width:520px){.eml-cell{width:32px;height:42px;font-size:15px}.eml-code{gap:5px}}
  CSS

  # ---- Quiet: centered, minimal, sans-serif, round icon chip, pill buttons. ----
  QUIET = <<~CSS
    .eml-card{--maxw:484px;padding:52px 48px 40px;text-align:center;font-family:var(--sans)}
    .eml-head{display:flex;align-items:center;justify-content:center;gap:9px;color:var(--ink-900);margin-bottom:40px}
    .eml-brand{font-size:16px;font-weight:700;letter-spacing:-.01em}
    .eml-pad{padding:0}
    .eml-headl{display:contents}.eml-tag{display:none}.eml-code-label{display:none}
    .eml-icon{width:68px;height:68px;border-radius:50%;background:var(--ink-100);color:var(--ink-900);display:flex;align-items:center;justify-content:center;margin:0 auto 26px;padding:19px}
    .eml-eyebrow{font-family:var(--mono);font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--ink-400);margin-bottom:14px}
    .eml-h1{font-size:25px;line-height:1.22;font-weight:700;letter-spacing:-.02em;color:var(--ink-900);margin:0 0 16px;text-wrap:balance}
    .eml-lead,.eml-p{font-size:15px;line-height:1.62;color:var(--ink-500);margin:0 auto 16px;max-width:340px;text-wrap:pretty}
    .eml-strong{color:var(--ink-900);font-weight:600}
    .eml-cta{margin:30px 0 8px}
    .eml-btn{display:inline-block;background:var(--ink-900);color:var(--paper);text-decoration:none;font-size:15px;font-weight:600;padding:15px 40px;border-radius:10px}
    .eml-code-wrap{margin:28px 0 10px}.eml-code{justify-content:center}
    .eml-note{font-size:13px;color:var(--ink-400);margin:14px auto 0;max-width:340px;line-height:1.55}
    .eml-fallback{margin:18px auto 0;text-align:left;max-width:380px}
    .eml-meta{margin:22px auto 6px;text-align:left;max-width:380px}
    .eml-alert{margin:0 auto 22px;max-width:380px;background:var(--ink-900);color:var(--paper);border-radius:10px;padding:14px 18px;font-size:13.5px;line-height:1.5;text-align:left}
    .eml-divider{height:1px;background:var(--ink-200);border:0;margin:36px 0 24px}
    .eml-foot{font-size:12px;line-height:1.65;color:var(--ink-400)}
    .eml-foot a{color:var(--ink-600);text-decoration:underline}
    .eml-foot-brand{display:flex;align-items:center;justify-content:center;gap:7px;color:var(--ink-300);margin-bottom:12px}
    @media (max-width:520px){.eml-card{padding:40px 24px 32px}.eml-h1{font-size:22px}}
  CSS

  # ---- Editorial: left-aligned, serif headline, 3px top rule, square edges. ----
  EDITORIAL = <<~CSS
    .eml-card{--maxw:564px;padding:0 0 36px;text-align:left;font-family:var(--sans);border-top:3px solid var(--ink-900)}
    .eml-pad{padding:40px 52px 0}
    .eml-head{display:flex;align-items:center;gap:9px;color:var(--ink-900);padding:26px 52px 0}
    .eml-brand{font-size:15px;font-weight:700;letter-spacing:-.01em}
    .eml-headl{display:contents}.eml-tag{display:none}.eml-code-label{display:none}
    .eml-icon{width:46px;height:46px;color:var(--ink-900);margin:34px 0 22px;padding:0}
    .eml-eyebrow{font-family:var(--mono);font-size:11px;letter-spacing:.22em;text-transform:uppercase;color:var(--ink-400);margin-bottom:18px}
    .eml-h1{font-family:var(--serif);font-size:34px;line-height:1.1;font-weight:700;color:var(--ink-900);margin:0 0 20px;letter-spacing:-.01em;text-wrap:balance}
    .eml-lead{font-size:17px;line-height:1.55;color:var(--ink-800);margin:0 0 18px;text-wrap:pretty}
    .eml-p{font-size:15.5px;line-height:1.62;color:var(--ink-600);margin:0 0 16px;text-wrap:pretty}
    .eml-strong{color:var(--ink-900);font-weight:700}
    .eml-cta{margin:30px 0 10px}
    .eml-btn{display:inline-block;background:var(--ink-900);color:var(--paper);text-decoration:none;font-size:15px;font-weight:600;padding:15px 36px;border-radius:0}
    .eml-code-wrap{margin:28px 0 12px}
    .eml-cell{border-radius:0}
    .eml-note{font-size:13px;color:var(--ink-400);margin:14px 0 0;line-height:1.55}
    .eml-fallback{margin:18px 0 0;border-radius:0}
    .eml-meta{margin:24px 0 6px;border-radius:0}
    .eml-alert{margin:0 0 24px;background:var(--ink-100);border-left:3px solid var(--ink-900);padding:15px 18px;font-size:14px;line-height:1.55;color:var(--ink-800)}
    .eml-divider{height:1px;background:var(--ink-200);border:0;margin:38px 52px 22px}
    .eml-foot{font-size:12px;line-height:1.7;color:var(--ink-400);padding:0 52px}
    .eml-foot a{color:var(--ink-700);text-decoration:underline}
    .eml-foot-brand{display:flex;align-items:center;gap:7px;color:var(--ink-300);margin-bottom:12px}
    @media (max-width:520px){.eml-pad,.eml-head,.eml-foot{padding-left:26px;padding-right:26px}.eml-divider{margin-left:26px;margin-right:26px}.eml-h1{font-size:27px}}
  CSS

  # ---- Structured: bordered card, header bar + tag chip, dark alert band. ----
  STRUCTURED = <<~CSS
    .eml-outer{padding:36px 16px}
    .eml-card{--maxw:592px;text-align:left;font-family:var(--sans);border:1px solid var(--ink-300);border-radius:14px;overflow:hidden}
    .eml-head{display:flex;align-items:center;justify-content:space-between;gap:9px;color:var(--ink-900);padding:16px 28px;border-bottom:1px solid var(--ink-200);background:var(--ink-50)}
    .eml-headl{display:flex;align-items:center;gap:9px}
    .eml-brand{font-size:15px;font-weight:700;letter-spacing:-.01em}
    .eml-tag{font-family:var(--mono);font-size:10.5px;letter-spacing:.12em;text-transform:uppercase;color:var(--ink-500);border:1px solid var(--ink-300);border-radius:999px;padding:4px 11px}
    .eml-pad{padding:34px 28px 28px}
    .eml-icon{width:48px;height:48px;border-radius:10px;background:var(--ink-100);color:var(--ink-900);display:flex;align-items:center;justify-content:center;margin:0 0 22px;padding:12px}
    .eml-eyebrow{display:none}
    .eml-h1{font-size:23px;line-height:1.25;font-weight:700;letter-spacing:-.015em;color:var(--ink-900);margin:0 0 14px;text-wrap:balance}
    .eml-lead,.eml-p{font-size:14.5px;line-height:1.62;color:var(--ink-600);margin:0 0 15px;text-wrap:pretty}
    .eml-strong{color:var(--ink-900);font-weight:600}
    .eml-cta{margin:26px 0 6px}
    .eml-btn{display:block;text-align:center;background:var(--ink-900);color:var(--paper);text-decoration:none;font-size:15px;font-weight:600;padding:15px 24px;border-radius:8px}
    .eml-code-wrap{margin:24px 0 8px;background:var(--ink-50);border:1px solid var(--ink-200);border-radius:10px;padding:20px}
    .eml-code-label{font-family:var(--mono);font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--ink-400);margin-bottom:12px}
    .eml-note{font-size:13px;color:var(--ink-400);margin:12px 0 0;line-height:1.55}
    .eml-fallback{margin:16px 0 0}
    .eml-meta{margin:22px 0 4px}
    .eml-alert{margin:0 0 22px;background:var(--ink-900);color:var(--paper);border-radius:10px;padding:15px 18px;font-size:13.5px;line-height:1.5}
    .eml-divider{display:none}
    .eml-foot{font-size:12px;line-height:1.65;color:var(--ink-400);background:var(--ink-50);padding:22px 28px;border-top:1px solid var(--ink-200)}
    .eml-foot a{color:var(--ink-700);text-decoration:underline}
    .eml-foot-brand{display:flex;align-items:center;gap:7px;color:var(--ink-400);margin-bottom:10px;font-weight:600}
    @media (max-width:520px){.eml-pad,.eml-head,.eml-foot{padding-left:20px;padding-right:20px}}
  CSS

  THEMES = {
    "quiet" => { css: QUIET, label: "Quiet", has_label: false },
    "editorial" => { css: EDITORIAL, label: "Editorial", has_label: false },
    "structured" => { css: STRUCTURED, label: "Structured", has_label: true }
  }.freeze

  # A full HTML document already carries its own <head>/<style>, so it must NOT be
  # wrapped (would nest <html> and double the styles). Matches both <!doctype ...>
  # and <html ...> case-insensitively (the ULP template uses uppercase <!DOCTYPE>).
  FULL_DOC = /<!doctype|<html[\s>]/i

  module_function

  def theme?(name)
    THEMES.key?(name.to_s)
  end

  # nil / unknown / blank -> the default theme; never raises so a bad ?theme= just
  # falls back instead of 4xx-ing.
  def normalize(name)
    theme?(name) ? name.to_s : DEFAULT_THEME
  end

  def full_document?(source)
    FULL_DOC.match?(source.to_s)
  end

  # Wrap a body fragment into a complete, uploadable HTML document for `theme`
  # (the prototype's `doc()`/`buildDoc()`). Tokens in `body` are left intact.
  def build_doc(theme, body)
    css = THEMES.fetch(normalize(theme))[:css]
    <<~HTML.chomp
      <!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light only"><style>#{BASE}#{css}</style></head><body>#{body}</body></html>
    HTML
  end

  # Compose the source Liquid passed to the renderer: wrap fragments with the theme,
  # pass full documents through unchanged. No Liquid evaluation happens here.
  def compose_source(theme, source)
    full_document?(source) ? source : build_doc(theme, source)
  end
end
