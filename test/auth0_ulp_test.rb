# frozen_string_literal: true

require "test_helper"
require "auth0_ulp"
require "renderer"
require "template_repo"

class Auth0UlpTest < Minitest::Test
  def test_detects_both_token_forms
    assert Auth0Ulp.tokens?("{%- auth0:head -%}")
    assert Auth0Ulp.tokens?("{% auth0:widget %}")
    assert Auth0Ulp.tokens?("before {%-  auth0:head  -%} after")
    refute Auth0Ulp.tokens?("<p>just an email, no tokens</p>")
  end

  def test_substitute_replaces_both_token_forms_with_the_approximation
    out = Auth0Ulp.substitute("A {%- auth0:head -%} B {% auth0:widget %} C")

    refute_includes out, "auth0:head"
    refute_includes out, "auth0:widget"
    assert_includes out, "auth0-head-approx" # the injected <style>
    assert_includes out, "w-card"            # the injected widget markup
    assert_includes out, "Bem-vindo de volta"
  end

  def test_substitute_leaves_token_free_source_untouched
    src = "<p>no tokens here</p>"
    assert_equal src, Auth0Ulp.substitute(src)
  end

  def test_universal_login_example_renders_to_widget_html
    repo = TemplateRepo.new(EXAMPLES_DIR)
    out = Renderer.new(repo: repo).render("universal_login")

    assert_includes out, "w-card"                          # injected widget markup
    assert_includes out, "Bem-vindo de volta"
    assert_includes out, "Acesse sua conta com segurança"  # the page wrapper rendered
    assert_includes out, "Acme"                            # {{ application.name }} resolved
    assert_includes out, "Acme Inc."                       # injected widget's own Liquid resolved

    # The original tokens do not survive into the output.
    refute_includes out, "auth0:head"
    refute_includes out, "auth0:widget"
  end

  def test_widget_falls_back_to_monogram_without_a_branding_logo
    repo = TemplateRepo.new(EXAMPLES_DIR)
    out = Renderer.new(repo: repo).render("universal_login")

    # No logo supplied (default branding.logo_url is "") -> the monogram <svg>, no <img>.
    assert_includes out, %(<div class="w-logo"><svg)
    refute_includes out, "w-logo-img"
  end

  def test_widget_renders_supplied_tenant_branding_logo
    repo = TemplateRepo.new(EXAMPLES_DIR)
    out = Renderer.new(repo: repo).render(
      "universal_login",
      overrides: { "branding" => { "logo_url" => "https://cdn.example.com/acme.svg" } }
    )

    assert_includes out, %(<img class="w-logo-img" src="https://cdn.example.com/acme.svg")
    # The monogram is not rendered inside the widget logo slot when a logo is present.
    # (The page chrome has its own brand SVG, so scope the check to the .w-logo div.)
    widget_logo = out[%r{<div class="w-logo">.*?</div>}m]
    refute_includes widget_logo, "<svg"
  end

  def test_organization_branding_logo_overrides_tenant_branding
    repo = TemplateRepo.new(EXAMPLES_DIR)
    out = Renderer.new(repo: repo).render(
      "universal_login",
      overrides: {
        "branding" => { "logo_url" => "https://cdn.example.com/tenant.svg" },
        "organization" => { "branding" => { "logo_url" => "https://cdn.example.com/org.svg" } }
      }
    )

    assert_includes out, "https://cdn.example.com/org.svg"
    refute_includes out, "https://cdn.example.com/tenant.svg"
  end

  def test_widget_escapes_a_branding_logo_url
    repo = TemplateRepo.new(EXAMPLES_DIR)
    out = Renderer.new(repo: repo).render(
      "universal_login",
      overrides: { "branding" => { "logo_url" => %(x"><script>alert(1)</script>) } }
    )

    refute_includes out, "<script>alert(1)</script>" # not injected verbatim into the attribute
    assert_includes out, "&lt;script&gt;"
  end

  def test_widget_logo_is_strict_mode_safe_without_branding_overrides
    repo = TemplateRepo.new(EXAMPLES_DIR)

    # branding / organization.branding are in the default context, so the logo lookup
    # must not raise Liquid::UndefinedVariable under strict mode.
    out = Renderer.new(repo: repo, strict: true).render("universal_login")
    assert_includes out, %(<div class="w-logo"><svg)
  end
end
