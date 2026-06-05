# frozen_string_literal: true

require "test_helper"
require "json"
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

  def test_index_lists_templates_grouped_for_the_previewer
    res = @request.get("/")
    assert_equal 200, res.status
    assert_includes res.body, "Onboarding"     # group headings (embedded as data)
    assert_includes res.body, "Segurança"
    assert_includes res.body, "Boas-vindas"    # a template title
    assert_includes res.body, "welcome_email"  # a template name
  end

  def test_index_ships_responsive_device_and_zoom_controls
    res = @request.get("/")
    assert_equal 200, res.status
    assert_includes res.body, "Responsivo (redimensionável)" # the 4th device option
    assert_includes res.body, "rsize-swap"                   # rotate (swap W×H) button
    assert_includes res.body, "zoom-reset"                   # zoom stepper
  end

  def test_render_returns_the_composed_email_html
    res = @request.get("/render/welcome_email")
    assert_equal 200, res.status
    assert_includes res.content_type, "text/html"
    assert_includes res.body, "Jane Doe"
    assert_includes res.body, "<!doctype html>" # fragment wrapped into a full doc
  end

  def test_raw_render_returns_rendered_plain_text
    res = @request.get("/render/welcome_email?_raw=1")
    assert_equal 200, res.status
    assert_includes res.content_type, "text/plain"
    assert_includes res.body, "Jane Doe"
    refute_includes res.body, "{{ application.name }}" # tokens were rendered, not echoed
  end

  def test_source_returns_token_intact_uploadable_document
    res = @request.get("/render/welcome_email?theme=quiet&source=1")
    assert_equal 200, res.status
    assert_includes res.content_type, "text/plain"
    assert_includes res.body, "{{ application.name }}" # tokens preserved verbatim
    assert_includes res.body, "{% if user.name %}"
    assert_includes res.body, "--maxw:484px"           # composed with the chosen theme
  end

  def test_theme_param_selects_the_stylesheet
    structured = @request.get("/render/welcome_email?theme=structured&_raw=1").body
    quiet = @request.get("/render/welcome_email?theme=quiet&_raw=1").body
    assert_includes structured, "border-radius:14px"
    refute_includes quiet, "border-radius:14px"
  end

  def test_unknown_theme_does_not_error
    res = @request.get("/render/welcome_email?theme=bogus")
    assert_equal 200, res.status
    assert_includes res.body, "--maxw:484px" # fell back to quiet
  end

  def test_query_param_overrides_top_level_key
    res = @request.get("/render/welcome_email?support_url=https://override.test/help&_raw=1")
    assert_equal 200, res.status
    assert_includes res.body, "https://override.test/help"
  end

  def test_post_json_body_deep_overrides_context
    body = JSON.dump("user" => { "name" => "Posted Name" })
    res = @request.post("/render/welcome_email?_raw=1",
                        input: body, "CONTENT_TYPE" => "application/json")
    assert_equal 200, res.status
    assert_includes res.body, "Posted Name"
  end

  def test_api_meta_returns_subject_sender_and_recipient
    res = @request.get("/api/meta/user_invitation")
    assert_equal 200, res.status
    assert_includes res.content_type, "application/json"
    data = JSON.parse(res.body)
    assert_equal "Alex Carter convidou você para a Acme Engenharia", data["subject"]
    assert_equal "Acme", data["from_name"]
    assert_equal "nao-responder@acme.com", data["from_addr"]
    assert_equal "newuser@example.com", data["to"]
  end

  def test_api_meta_reflects_overrides
    body = JSON.dump("inviter" => { "name" => "Maria" })
    res = @request.post("/api/meta/user_invitation",
                        input: body, "CONTENT_TYPE" => "application/json")
    assert_equal 200, res.status
    assert_includes JSON.parse(res.body)["subject"], "Maria convidou você"
  end

  def test_api_meta_unknown_template_is_404
    res = @request.get("/api/meta/does_not_exist")
    assert_equal 404, res.status
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
