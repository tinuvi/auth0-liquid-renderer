# frozen_string_literal: true

require "liquid"
require_relative "default_context"
require_relative "auth0_ulp"
require_relative "email_theme"

# PURE rendering core: (template_name, overrides, theme) -> rendered String. No HTTP
# lives here (routing is in app.rb), so this is trivially unit-testable.
#
# Merge order, later wins: built-in defaults < fixture vars < overrides.
# A scalar override (query-string param) replaces a top-level key; a nested override
# (POSTed JSON) deep-merges. Both fall out of deep_merge naturally.
#
# Two string-transform passes prepare the source BEFORE Liquid parses it (both keep
# the on-disk .liquid uploadable verbatim — they run on an in-memory copy):
#   - EmailTheme: a body fragment is wrapped with the chosen theme's <head>/<style>;
#     a source that is already a full document passes through unthemed.
#   - Auth0Ulp: auth0:head/widget tokens are swapped for representative head/widget
#     HTML; the injected widget itself carries Liquid, so it resolves in the same pass.
class Renderer
  def initialize(repo:, strict: false)
    @repo = repo
    @strict = strict
  end

  # Renders <name>.liquid with the resolved context, composed with `theme` (fragments
  # only). Raises Liquid::Error (including Liquid::UndefinedVariable under strict mode)
  # so callers surface failures instead of returning a blank page.
  def render(name, overrides: {}, theme: nil)
    context = resolve(name, overrides)
    composed = EmailTheme.compose_source(EmailTheme.normalize(theme), @repo.source(name))
    source = Auth0Ulp.substitute(composed)
    Liquid::Template.parse(source).render!(context, strict_variables: @strict)
  end

  # The fully-resolved context without rendering — used to pre-fill the previewer's
  # variable editor.
  def context_for(name, overrides: {})
    resolve(name, overrides)
  end

  # Renders the template's `_meta.subject` (itself a Liquid string) with the resolved
  # context. Returns "" when no subject is declared. Used for the email-client chrome.
  def render_subject(name, overrides: {})
    subject = @repo.fixture(name)["meta"]["subject"].to_s
    return "" if subject.empty?

    Liquid::Template.parse(subject).render!(resolve(name, overrides), strict_variables: @strict)
  end

  # The "From" shown in the previewer's email-client chrome, derived from the resolved
  # application.name (brand-neutral fallback "Acme"). Mirrors the design prototype.
  def sender_for(name, overrides: {})
    app = resolve(name, overrides)["application"]
    app_name = (app.is_a?(Hash) ? app["name"].to_s : "")
    app_name = "Acme" if app_name.empty?
    slug = app_name.downcase.gsub(/[^a-z0-9]/, "")
    slug = "acme" if slug.empty?
    { name: app_name, addr: "nao-responder@#{slug}.com" }
  end

  private

  def resolve(name, overrides)
    base = deep_merge(DefaultContext.call, @repo.fixture(name)["vars"])
    deep_merge(base, stringify(overrides))
  end

  def deep_merge(base, other)
    base.merge(other) do |_key, base_val, other_val|
      if base_val.is_a?(Hash) && other_val.is_a?(Hash)
        deep_merge(base_val, other_val)
      else
        other_val
      end
    end
  end

  # JSON and query params already arrive string-keyed, but symbol-keyed overrides from
  # Ruby callers (tests) are normalized so Liquid's string lookups resolve them.
  def stringify(value)
    case value
    when Hash then value.each_with_object({}) { |(k, v), acc| acc[k.to_s] = stringify(v) }
    when Array then value.map { |v| stringify(v) }
    else value
    end
  end
end
