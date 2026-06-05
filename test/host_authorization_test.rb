# frozen_string_literal: true

require "test_helper"
require "rack/mock"
require "app"

# Covers the ALLOWED_HOSTS env var: the pure mapping to Sinatra's host_authorization
# options, and that those options actually allow/deny through Rack::Protection.
class HostAuthorizationTest < Minitest::Test
  NGROK = "abcd-1-2-3-4.ngrok-free.app"

  # --- unit: ALLOWED_HOSTS string -> host_authorization options ---

  def test_unset_or_blank_keeps_sinatra_default
    assert_nil App.host_authorization_config(nil)
    assert_nil App.host_authorization_config("")
    assert_nil App.host_authorization_config("  , ,  ")
  end

  def test_star_permits_any_host
    assert_equal({ permitted_hosts: [] }, App.host_authorization_config("*"))
    assert_equal({ permitted_hosts: [] }, App.host_authorization_config("a.example.com, *"))
  end

  def test_listed_hosts_are_added_to_localhost_defaults
    hosts = App.host_authorization_config("#{NGROK}, .example.com ")[:permitted_hosts]
    assert_includes hosts, NGROK
    assert_includes hosts, ".example.com"
    assert_includes hosts, "localhost" # localhost stays permitted, so you can't lock yourself out
  end

  # --- integration: the options actually gate requests via Rack::Protection ---

  def test_default_blocks_foreign_host_but_allows_localhost
    app = build_app(nil)
    assert_equal 403, request(app, "evil.example.com").status
    assert_equal 200, request(app, "localhost").status
  end

  def test_star_allows_a_foreign_host
    assert_equal 200, request(build_app("*"), NGROK).status
  end

  def test_listed_host_allowed_others_denied
    app = build_app(NGROK)
    assert_equal 200, request(app, NGROK).status           # the permitted tunnel host
    assert_equal 200, request(app, "localhost").status     # localhost still works
    assert_equal 403, request(app, "other.example.com").status
  end

  private

  def build_app(allowed_hosts_value)
    options = App.host_authorization_config(allowed_hosts_value)
    Sinatra.new do
      set :environment, :development # deterministic: dev enables the localhost default
      set :raise_errors, false
      set :show_exceptions, false
      set(:host_authorization, options) if options
      get("/") { "OK" }
    end
  end

  def request(app, host)
    Rack::MockRequest.new(app).get("/", "HTTP_HOST" => host)
  end
end
