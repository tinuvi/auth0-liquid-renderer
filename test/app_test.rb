# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rack/mock"
require "app"

# Drives the Sinatra app in-process via Rack::MockRequest (no rack-test gem).
class AppTest < Minitest::Test
  def setup
    @request = Rack::MockRequest.new(App)
    @saved_env = ENV.to_hash.slice("TEMPLATES_DIR", "STRICT_VARIABLES")
    ENV["TEMPLATES_DIR"] = EXAMPLES_DIR
  end

  def teardown
    %w[TEMPLATES_DIR STRICT_VARIABLES].each { |k| ENV.delete(k) }
    @saved_env.each { |k, v| ENV[k] = v }
  end

  def test_index_lists_templates_grouped_by_kind
    res = @request.get("/")
    assert_equal 200, res.status
    assert_includes res.body, "verify_email"
    assert_includes res.body, "Email templates"
    assert_includes res.body, "Universal Login"
  end

  def test_render_page_returns_200
    res = @request.get("/render/welcome_email")
    assert_equal 200, res.status
    assert_includes res.body, "Jane Doe"
  end

  def test_raw_render_returns_plain_text
    res = @request.get("/render/welcome_email?_raw=1")
    assert_equal 200, res.status
    assert_includes res.content_type, "text/plain"
    assert_includes res.body, "Jane Doe"
  end

  def test_query_param_overrides_top_level_key
    res = @request.get("/render/welcome_email?friendly_name=QueryName&_raw=1")
    assert_equal 200, res.status
    assert_includes res.body, "QueryName"
  end

  def test_post_json_body_deep_overrides_context
    body = JSON.dump("user" => { "name" => "Posted Name" })
    res = @request.post("/render/welcome_email?_raw=1",
                        input: body, "CONTENT_TYPE" => "application/json")
    assert_equal 200, res.status
    assert_includes res.body, "Posted Name"
  end

  def test_unknown_template_returns_404
    res = @request.get("/render/does_not_exist")
    assert_equal 404, res.status
    assert_includes res.body, "Unknown template"
    assert_includes res.body, "welcome_email" # lists what IS available
  end

  def test_broken_template_does_not_return_blank_200
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "broken.liquid"), "Hello {{ this_variable_is_not_defined }}")
      ENV["TEMPLATES_DIR"] = dir
      ENV["STRICT_VARIABLES"] = "1" # surface the undefined reference as an error

      res = @request.get("/render/broken")
      assert_equal 422, res.status
      refute_empty res.body
      assert_includes res.body, "this_variable_is_not_defined"
    end
  end
end
