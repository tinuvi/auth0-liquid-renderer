# frozen_string_literal: true

require "test_helper"
require "json"
require "tmpdir"
require "fileutils"
require "renderer"
require "template_repo"

class RendererTest < Minitest::Test
  # Curated "key values" each bundled example must surface. These come from the
  # fixtures in examples/_fixtures/ (now pt-BR).
  KEY_VALUES = {
    # NOTE: OTP codes (verify_email_by_code, reset_email_by_code, mfa_oob_code) render
    # as per-character cells, so the raw code is not a contiguous substring — those are
    # asserted in test_otp_codes_render_as_individual_character_cells instead.
    "verify_email" => ["jane.doe@example.com", "VERIFY-TOKEN-123", "https://acme.example.com/support"],
    "verify_email_by_code" => ["jane.doe@example.com", "Seu código"],
    "welcome_email" => ["Jane Doe", "Acme"],
    "enrollment_email" => ["jane.doe@example.com", "ENROLL-456"],
    "reset_email" => ["jane.doe@example.com", "RESET-789"],
    "reset_email_full" => ["Acme", "Você solicitou a troca de senha", "RESET-FULL-789"],
    "reset_email_by_code" => ["jane.doe@example.com", "Código de redefinição"],
    "blocked_account" => ["Springfield", "Estados Unidos", "203.0.113.42", "UNBLOCK-321"],
    "stolen_credentials" => ["jane.doe@example.com", "BREACH-654"],
    "mfa_oob_code" => ["jane.doe@example.com", "Código de acesso"],
    "user_invitation" => ["newuser@example.com", "Alex Carter", "Acme Engenharia", "INVITE-987"],
    "universal_login" => ["Acme", "Acesse sua conta com segurança", "Bem-vindo de volta", "Continuar"],
    "error_page" => ["Acme", "access_denied", "Acesso negado", "a1b2c3d4e5f6a7b8"]
  }.freeze

  def setup
    @repo = TemplateRepo.new(EXAMPLES_DIR)
    @renderer = Renderer.new(repo: @repo)
  end

  def test_every_example_is_covered_and_renders_without_error
    assert_equal 13, @repo.names.length, "expected 13 bundled examples"
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

  def test_email_fragments_are_wrapped_into_a_full_themed_document
    output = @renderer.render("welcome_email", theme: "quiet")
    assert_includes output, "<!doctype html>"
    assert_includes output, '<html lang="pt-BR">'
    assert_includes output, "--maxw:484px"            # quiet theme stylesheet
    assert_includes output, "Sua conta na Acme"       # the rendered body
  end

  def test_each_theme_changes_the_rendered_stylesheet
    quiet = @renderer.render("welcome_email", theme: "quiet")
    editorial = @renderer.render("welcome_email", theme: "editorial")
    structured = @renderer.render("welcome_email", theme: "structured")

    assert_includes quiet, "--maxw:484px"
    assert_includes editorial, "border-top:3px solid var(--ink-900)"
    assert_includes structured, "border-radius:14px"
    refute_includes quiet, "border-radius:14px"
  end

  def test_unknown_theme_falls_back_to_quiet
    assert_equal @renderer.render("welcome_email", theme: "quiet"),
                 @renderer.render("welcome_email", theme: "nonsense")
  end

  def test_full_document_templates_are_not_themed
    output = @renderer.render("universal_login", theme: "structured")
    refute_includes output, "eml-outer"   # no email-fragment markup
    refute_includes output, "--ink-900"   # no email-theme stylesheet injected
    assert_includes output, "w-card"      # the ULP widget still renders
  end

  def test_otp_codes_render_as_individual_character_cells
    codes = { "mfa_oob_code" => "OOB-9931", "verify_email_by_code" => "ACME-7Q2X", "reset_email_by_code" => "RST-55AA" }
    codes.each do |name, code|
      output = @renderer.render(name)
      expected = code.chars.map do |c|
        c == "-" ? '<span class="eml-dash">-</span>' : %(<span class="eml-cell">#{c}</span>)
      end.join
      assert_includes output, expected, "expected #{name} to render #{code} as character cells"
    end
  end

  def test_render_subject_renders_the_liquid_subject_string
    assert_equal "Alex Carter convidou você para a Acme Engenharia",
                 @renderer.render_subject("user_invitation")
    overridden = @renderer.render_subject("user_invitation", overrides: { "inviter" => { "name" => "Maria" } })
    assert_equal "Maria convidou você para a Acme Engenharia", overridden
  end

  def test_render_subject_is_empty_without_a_subject_meta
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "x.liquid"), "<p>hi</p>")
      assert_equal "", Renderer.new(repo: TemplateRepo.new(dir)).render_subject("x")
    end
  end

  def test_sender_for_derives_address_from_application_name
    assert_equal({ name: "Acme", addr: "nao-responder@acme.com" }, @renderer.sender_for("welcome_email"))
    overridden = @renderer.sender_for("welcome_email", overrides: { "application" => { "name" => "Globex Inc" } })
    assert_equal({ name: "Globex Inc", addr: "nao-responder@globexinc.com" }, overridden)
  end

  def test_merge_precedence_defaults_then_fixture_then_override
    Dir.mktmpdir do |dir|
      # A full document is rendered verbatim (no theme wrapping), so we can assert exact output.
      File.write(File.join(dir, "t.liquid"), "<!doctype html><p>name={{ application.name }} tenant={{ tenant }}</p>")
      FileUtils.mkdir_p(File.join(dir, "_fixtures"))
      File.write(File.join(dir, "_fixtures", "t.json"),
                 JSON.dump({ "application" => { "name" => "FixtureCo" } }))
      renderer = Renderer.new(repo: TemplateRepo.new(dir))

      # tenant comes from defaults (no fixture/override); application.name from fixture (beats default).
      assert_equal "<!doctype html><p>name=FixtureCo tenant=acme</p>", renderer.render("t")

      # override beats fixture; deep-merge preserves the untouched default tenant.
      overridden = renderer.render("t", overrides: { "application" => { "name" => "OverrideCo" } })
      assert_equal "<!doctype html><p>name=OverrideCo tenant=acme</p>", overridden
    end
  end

  def test_error_page_renders_default_scenario_as_unthemed_full_document
    output = @renderer.render("error_page", theme: "structured")
    assert_includes output, "<!doctype html>"
    refute_includes output, "eml-outer"            # not wrapped in an email theme
    refute_includes output, "--ink-900"            # no email-theme stylesheet injected
    assert_includes output, "access_denied"        # the error-code chip
    assert_includes output, "Acesso negado"        # the {% case error %} branch for that code
  end

  # The crux of the gap report: the error-page variables must resolve from the built-in
  # defaults even with NO fixture, so a mounted error template is not stuck on the blank
  # fallback. (`connection` already existed; the other five are the surface contract.)
  def test_error_page_variables_resolve_from_defaults_without_a_fixture
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "err.liquid"),
                 "<!doctype html><p>{{ error }}|{{ error_description }}|{{ tracking }}|" \
                 "{{ lang }}|{{ client_id }}|{{ connection }}</p>")
      output = Renderer.new(repo: TemplateRepo.new(dir)).render("err")
      assert_includes output, "access_denied"
      assert_includes output, "do not have permission"
      assert_includes output, "acme-tracking-id"
      assert_includes output, "Username-Password-Authentication"
      assert_includes output, "acme-client-id"
    end
  end

  def test_error_page_case_switches_on_the_error_code
    output = @renderer.render("error_page", overrides: { "error" => "server_error" })
    assert_includes output, "server_error"      # chip reflects the override
    assert_includes output, "Erro no servidor"  # the matching branch
    refute_includes output, "Acesso negado"     # the default branch is gone
  end

  # Auth0 documents that error variables (request-influenced) must be escaped to avoid XSS;
  # the bundled template models that, so a script payload must arrive inert.
  def test_error_page_escapes_request_influenced_variables
    output = @renderer.render("error_page", overrides: { "error_description" => "<script>alert(1)</script>" })
    assert_includes output, "&lt;script&gt;alert(1)&lt;/script&gt;"
    refute_includes output, "<script>alert(1)</script>"
  end

  def test_context_for_resolves_without_rendering
    context = @renderer.context_for("verify_email")
    assert_equal "jane.doe@example.com", context.dig("user", "email")
    assert_equal "https://acme.example.com/support", context["support_url"]
  end
end
