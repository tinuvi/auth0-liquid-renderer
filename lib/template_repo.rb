# frozen_string_literal: true

require "json"
require_relative "auth0_ulp"

# Scans TEMPLATES_DIR for templates and fixtures, reading fresh from disk on EVERY
# call so editing a file and refreshing the browser shows the change with no restart
# (HANDOFF §3.1 hot reload). Nothing is cached across requests.
#
# A template is a top-level *.liquid file; its name is the basename without extension
# (verify_email.liquid -> "verify_email"). Anything under _fixtures/ and any
# non-.liquid file is not a template and never appears in the index.
class TemplateRepo
  FIXTURES_DIR = "_fixtures"

  def initialize(dir)
    @dir = dir.to_s
  end

  attr_reader :dir

  # Top-level template names, sorted. Excludes _fixtures/ and non-.liquid files.
  def names
    return [] unless Dir.exist?(@dir)

    Dir.children(@dir)
       .select { |f| f.end_with?(".liquid") && File.file?(File.join(@dir, f)) }
       .map { |f| File.basename(f, ".liquid") }
       .sort
  end

  def exist?(name)
    File.file?(path_for(name))
  end

  def source(name)
    File.read(path_for(name))
  end

  # { "vars" => Hash, "meta" => Hash } — _meta split out of the fixture JSON.
  def fixture(name)
    file = File.join(@dir, FIXTURES_DIR, "#{File.basename(name)}.json")
    return { "vars" => {}, "meta" => {} } unless File.file?(file)

    data = JSON.parse(File.read(file))
    data = {} unless data.is_a?(Hash)
    meta = data["_meta"].is_a?(Hash) ? data["_meta"] : {}
    { "vars" => data.except("_meta"), "meta" => meta }
  end

  # Index rows for the UI: [{ name:, title:, description:, kind: }], sorted by name.
  def entries
    names.map do |name|
      meta = fixture(name)["meta"]
      {
        name: name,
        title: meta["title"] || humanize(name),
        description: meta["description"],
        kind: meta["kind"] || derive_kind(name)
      }
    end
  end

  private

  # File.basename guards against path traversal via the :name route segment.
  def path_for(name)
    File.join(@dir, "#{File.basename(name)}.liquid")
  end

  def derive_kind(name)
    Auth0Ulp.tokens?(source(name)) ? "universal_login" : "email"
  end

  def humanize(name)
    name.split(/[_-]/).map(&:capitalize).join(" ")
  end
end
