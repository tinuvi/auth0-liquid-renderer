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
end
