# frozen_string_literal: true

require "test_helper"
require "json"
require "tmpdir"
require "fileutils"
require "renderer"
require "template_repo"

class RendererTest < Minitest::Test
  # Curated "key values" each bundled example must surface. These come from the
  # fixtures in examples/_fixtures/.
  KEY_VALUES = {
    "verify_email" => ["jane.doe@example.com", "VERIFY-TOKEN-123", "https://acme.example.com/support"],
    "verify_email_by_code" => ["jane.doe@example.com", "ACME-7Q2X"],
    "welcome_email" => ["Jane Doe", "Acme"],
    "enrollment_email" => ["jane.doe@example.com", "ENROLL-456"],
    "reset_email" => ["jane.doe@example.com", "RESET-789"],
    "reset_email_by_code" => ["jane.doe@example.com", "RST-55AA"],
    "blocked_account" => ["Springfield", "United States", "203.0.113.42", "UNBLOCK-321"],
    "stolen_credentials" => ["jane.doe@example.com", "BREACH-654"],
    "mfa_oob_code" => ["jane.doe@example.com", "OOB-9931"],
    "user_invitation" => ["newuser@example.com", "Alex Carter", "Acme Engineering", "INVITE-987"],
    "universal_login" => ["Sign in to Acme", "_widget login", "react-components"]
  }.freeze

  def setup
    @repo = TemplateRepo.new(EXAMPLES_DIR)
    @renderer = Renderer.new(repo: @repo)
  end

  def test_every_example_is_covered_and_renders_without_error
    assert_equal 11, @repo.names.length, "expected 11 bundled examples"
    @repo.names.each do |name|
      output = @renderer.render(name)
      refute_empty output.strip, "#{name} rendered empty"
      assert KEY_VALUES.key?(name), "no key-value expectations declared for #{name}"
    end
  end

  def test_each_example_output_contains_its_key_values
    KEY_VALUES.each do |name, values|
      output = @renderer.render(name)
      values.each do |value|
        assert_includes output, value, "expected #{name} output to contain #{value.inspect}"
      end
    end
  end

  def test_merge_precedence_defaults_then_fixture_then_override
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "t.liquid"), "name={{ application.name }} tenant={{ tenant }}")
      FileUtils.mkdir_p(File.join(dir, "_fixtures"))
      File.write(File.join(dir, "_fixtures", "t.json"),
                 JSON.dump({ "application" => { "name" => "FixtureCo" } }))
      renderer = Renderer.new(repo: TemplateRepo.new(dir))

      # tenant comes from defaults (no fixture/override); application.name from fixture (beats default).
      assert_equal "name=FixtureCo tenant=acme", renderer.render("t")

      # override beats fixture; deep-merge preserves the untouched default tenant.
      overridden = renderer.render("t", overrides: { "application" => { "name" => "OverrideCo" } })
      assert_equal "name=OverrideCo tenant=acme", overridden
    end
  end

  def test_context_for_resolves_without_rendering
    context = @renderer.context_for("verify_email")
    assert_equal "jane.doe@example.com", context.dig("user", "email")
    assert_equal "https://acme.example.com/support", context["support_url"]
  end
end
