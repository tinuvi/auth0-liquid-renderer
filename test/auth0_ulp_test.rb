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

  def test_to_sentinels_replaces_both_token_forms
    source = "A {%- auth0:head -%} B {% auth0:widget %} C"
    out = Auth0Ulp.to_sentinels(source)

    refute_includes out, "auth0:head"
    refute_includes out, "auth0:widget"
    assert_includes out, Auth0Ulp::HEAD_SENTINEL
    assert_includes out, Auth0Ulp::WIDGET_SENTINEL
  end

  def test_from_sentinels_swaps_html_with_configured_version
    sentineled = "#{Auth0Ulp::HEAD_SENTINEL}|#{Auth0Ulp::WIDGET_SENTINEL}"
    out = Auth0Ulp.from_sentinels(sentineled, cdn_version: "9.9.9")

    assert_includes out, "react-components/9.9.9/css/main.cdn.min.css"
    assert_includes out, "_widget login"
    refute_includes out, Auth0Ulp::HEAD_SENTINEL
    refute_includes out, Auth0Ulp::WIDGET_SENTINEL
  end

  def test_universal_login_example_renders_to_widget_html
    repo = TemplateRepo.new(EXAMPLES_DIR)
    out = Renderer.new(repo: repo, cdn_version: "1.59.25").render("universal_login")

    assert_includes out, "react-components/1.59.25/css/main.cdn.min.css"
    assert_includes out, "_widget login"
    assert_includes out, "Sign in to Acme" # the {{ application.name }} Liquid var was rendered

    # Neither the original tokens nor the internal sentinels survive.
    refute_includes out, "auth0:head"
    refute_includes out, "auth0:widget"
    refute_includes out, Auth0Ulp::HEAD_SENTINEL
    refute_includes out, Auth0Ulp::WIDGET_SENTINEL
  end
end
