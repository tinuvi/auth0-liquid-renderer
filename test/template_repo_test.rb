# frozen_string_literal: true

require "test_helper"
require "json"
require "tmpdir"
require "fileutils"
require "template_repo"

class TemplateRepoTest < Minitest::Test
  def test_lists_only_top_level_liquid_files
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "welcome_email.liquid"), "hi")
      File.write(File.join(dir, "universal_login.liquid"), "page")
      File.write(File.join(dir, "notes.txt"), "ignored")
      File.write(File.join(dir, "README.md"), "ignored")
      FileUtils.mkdir_p(File.join(dir, "_fixtures"))
      File.write(File.join(dir, "_fixtures", "welcome_email.json"), "{}")
      FileUtils.mkdir_p(File.join(dir, "nested"))
      File.write(File.join(dir, "nested", "deep.liquid"), "ignored")

      repo = TemplateRepo.new(dir)
      assert_equal %w[universal_login welcome_email], repo.names
    end
  end

  def test_missing_directory_yields_no_names
    assert_empty TemplateRepo.new("/no/such/dir/here").names
  end

  def test_fixture_splits_meta_from_vars
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "x.liquid"), "x")
      FileUtils.mkdir_p(File.join(dir, "_fixtures"))
      File.write(File.join(dir, "_fixtures", "x.json"), JSON.dump(
                                                          "_meta" => { "title" => "Title X", "kind" => "email" },
                                                          "user" => { "email" => "e@example.com" }
                                                        ))

      fixture = TemplateRepo.new(dir).fixture("x")
      assert_equal({ "title" => "Title X", "kind" => "email" }, fixture["meta"])
      assert_equal({ "user" => { "email" => "e@example.com" } }, fixture["vars"])
    end
  end

  def test_fixture_absent_returns_empty_vars_and_meta
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "x.liquid"), "x")
      fixture = TemplateRepo.new(dir).fixture("x")
      assert_empty fixture["vars"]
      assert_empty fixture["meta"]
    end
  end

  def test_entries_derive_title_and_kind
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "page.liquid"), "<head>{%- auth0:head -%}</head>{%- auth0:widget -%}")
      File.write(File.join(dir, "plain_mail.liquid"), "<p>hello</p>")
      repo = TemplateRepo.new(dir)
      entries = repo.entries

      page = entries.find { |e| e[:name] == "page" }
      mail = entries.find { |e| e[:name] == "plain_mail" }

      assert_equal "universal_login", page[:kind]
      assert_equal "email", mail[:kind]
      assert_equal "Plain Mail", mail[:title] # humanized from filename when no _meta
      assert_nil mail[:group] # absent from _meta -> nil
      assert_nil mail[:subject]
    end
  end

  def test_entries_expose_group_and_subject_from_meta
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "m.liquid"), "<div>hi</div>")
      FileUtils.mkdir_p(File.join(dir, "_fixtures"))
      File.write(File.join(dir, "_fixtures", "m.json"),
                 JSON.dump("_meta" => { "title" => "M", "group" => "Onboarding",
                                        "subject" => "Oi {{ application.name }}" }))

      entry = TemplateRepo.new(dir).entries.first
      assert_equal "Onboarding", entry[:group]
      assert_equal "Oi {{ application.name }}", entry[:subject]
    end
  end

  def test_entries_derive_error_page_kind_from_filename
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "error_page.liquid"), "<!doctype html><p>{{ error }}</p>")
      File.write(File.join(dir, "error.liquid"), "<!doctype html><p>oops</p>")
      File.write(File.join(dir, "welcome_email.liquid"), "<p>hi</p>")
      entries = TemplateRepo.new(dir).entries

      assert_equal "error_page", entries.find { |e| e[:name] == "error_page" }[:kind]
      assert_equal "error_page", entries.find { |e| e[:name] == "error" }[:kind]
      assert_equal "email", entries.find { |e| e[:name] == "welcome_email" }[:kind] # unaffected
    end
  end

  def test_meta_kind_overrides_token_detection
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "page.liquid"), "{%- auth0:widget -%}")
      FileUtils.mkdir_p(File.join(dir, "_fixtures"))
      File.write(File.join(dir, "_fixtures", "page.json"),
                 JSON.dump("_meta" => { "title" => "Forced Email", "kind" => "email" }))

      entry = TemplateRepo.new(dir).entries.first
      assert_equal "email", entry[:kind]
      assert_equal "Forced Email", entry[:title]
    end
  end
end
