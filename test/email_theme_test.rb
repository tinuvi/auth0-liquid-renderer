# frozen_string_literal: true

require "test_helper"
require "email_theme"

class EmailThemeTest < Minitest::Test
  FRAGMENT = '<div class="eml-outer"><div class="eml-card">hello</div></div>'

  # A representative CSS marker unique to each theme's stylesheet.
  THEME_MARKERS = {
    "quiet" => "--maxw:484px",
    "editorial" => "border-top:3px solid var(--ink-900)",
    "structured" => "border-radius:14px"
  }.freeze

  def test_full_document_detects_complete_html
    assert EmailTheme.full_document?("<!doctype html><html><body>x</body></html>")
    assert EmailTheme.full_document?("<!DOCTYPE html>\n<html lang=\"en\">") # uppercase (ULP template)
    assert EmailTheme.full_document?("<html>x</html>")
    refute EmailTheme.full_document?(FRAGMENT)
    refute EmailTheme.full_document?("just text")
  end

  def test_build_doc_wraps_fragment_into_full_pt_br_document
    doc = EmailTheme.build_doc("quiet", FRAGMENT)
    assert_includes doc, "<!doctype html>"
    assert_includes doc, '<html lang="pt-BR">'
    assert_includes doc, "--ink-900" # shared BASE tokens
    assert_includes doc, FRAGMENT    # body preserved verbatim
  end

  def test_each_theme_injects_its_own_stylesheet
    THEME_MARKERS.each do |theme, marker|
      doc = EmailTheme.build_doc(theme, FRAGMENT)
      assert_includes doc, marker, "expected #{theme} doc to carry #{marker.inspect}"
      other = THEME_MARKERS.reject { |t, _| t == theme }.values
      other.each { |m| refute_includes doc, m, "#{theme} doc should not carry #{m.inspect}" }
    end
  end

  def test_normalize_falls_back_to_quiet
    assert_equal "quiet", EmailTheme.normalize(nil)
    assert_equal "quiet", EmailTheme.normalize("")
    assert_equal "quiet", EmailTheme.normalize("nonsense")
    assert_equal "editorial", EmailTheme.normalize("editorial")
    assert_equal "structured", EmailTheme.normalize(:structured)
  end

  def test_theme_predicate_and_order
    assert EmailTheme.theme?("structured")
    refute EmailTheme.theme?("nope")
    assert_equal %w[quiet editorial structured], EmailTheme::THEME_ORDER
  end

  def test_build_doc_with_unknown_theme_uses_quiet
    assert_includes EmailTheme.build_doc("nope", FRAGMENT), THEME_MARKERS["quiet"]
  end

  def test_compose_source_passes_full_documents_through_unchanged
    full = "<!doctype html><html><head></head><body>{%- auth0:widget -%}</body></html>"
    assert_equal full, EmailTheme.compose_source("structured", full)
  end

  def test_compose_source_wraps_fragments
    composed = EmailTheme.compose_source("editorial", FRAGMENT)
    assert EmailTheme.full_document?(composed)
    assert_includes composed, FRAGMENT
    assert_includes composed, THEME_MARKERS["editorial"]
  end
end
