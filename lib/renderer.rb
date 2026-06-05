# frozen_string_literal: true

require "liquid"
require_relative "default_context"
require_relative "auth0_ulp"

# PURE rendering core: (template_name, overrides) -> rendered String. No HTTP lives
# here (routing is in app.rb), so this is trivially unit-testable.
#
# Merge order, later wins: built-in defaults < fixture vars < overrides.
# A scalar override (query-string param) replaces a top-level key; a nested override
# (POSTed JSON) deep-merges. Both fall out of deep_merge naturally.
#
# ULP tokens are handled by a substitution pass around Liquid (see Auth0Ulp): the raw
# source has its auth0:head/widget tokens swapped for sentinels BEFORE parse, and the
# sentinels are swapped for head/widget HTML AFTER render — so the .liquid stays
# uploadable to Auth0 verbatim and Liquid never re-processes the injected HTML.
class Renderer
  def initialize(repo:, strict: false, cdn_version: Auth0Ulp::DEFAULT_CDN_VERSION)
    @repo = repo
    @strict = strict
    @cdn_version = cdn_version
  end

  # Renders <name>.liquid with the resolved context. Raises Liquid::Error (including
  # Liquid::UndefinedVariable under strict mode) so callers surface failures instead
  # of returning a blank page.
  def render(name, overrides: {})
    context = resolve(name, overrides)
    source = Auth0Ulp.to_sentinels(@repo.source(name))
    output = Liquid::Template.parse(source).render!(context, strict_variables: @strict)
    Auth0Ulp.from_sentinels(output, cdn_version: @cdn_version)
  end

  # The fully-resolved context without rendering — used to pre-fill the render page's
  # JSON textarea.
  def context_for(name, overrides: {})
    resolve(name, overrides)
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
