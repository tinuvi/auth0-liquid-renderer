# frozen_string_literal: true

require "sinatra/base"
require "json"
require "ipaddr"
require_relative "template_repo"
require_relative "renderer"
require_relative "auth0_ulp"
require_relative "email_theme"

# The Sinatra app: the renderer's HTTP routes, rendering the renderer's OWN UI. All
# HTTP lives here; the rendering logic stays in Renderer. A fresh TemplateRepo +
# Renderer are built per request from current ENV so file edits hot-reload and tests
# stay isolated.
class App < Sinatra::Base
  EXAMPLES_DIR = File.expand_path("../examples", __dir__)
  # `theme` and `source` select the rendering/export mode; they must never leak into
  # the Liquid context as overrides.
  EXCLUDED_PARAMS = %w[name _raw source theme splat captures].freeze
  # Sidebar section order for the previewer; templates without a known group fall into
  # a trailing "Outros" bucket (e.g. the Universal Login page).
  GROUP_ORDER = ["Onboarding", "Acesso à conta", "Segurança", "Universal Login"].freeze

  set :views, File.expand_path("ui", __dir__)
  # We always render our own pages (incl. errors), so turn off Sinatra's defaults
  # that would otherwise raise in test env or emit a blank/HTML-debug response.
  set :raise_errors, false
  set :show_exceptions, false
  set :dump_errors, false

  # Sinatra 4 blocks requests whose Host (or X-Forwarded-Host) is not in its
  # permitted list. That is right for localhost, but it 403s ("Host not permitted")
  # when you preview the app over a LAN hostname or a tunnel (ngrok, Cloudflare).
  # ALLOWED_HOSTS (comma-separated, Django-style) opts extra hostnames in; "*"
  # permits any host. Localhost/loopback always stay permitted so you can't lock
  # yourself out. Read once at boot — set it in the container's environment.
  #
  # Examples:
  #   ALLOWED_HOSTS="abcd-1-2-3-4.ngrok-free.app"   # one tunnel host
  #   ALLOWED_HOSTS=".example.com,192.168.1.20"     # a subdomain wildcard + a LAN IP
  #   ALLOWED_HOSTS="*"                              # any host (handy for a quick demo)
  def self.host_authorization_config(raw = ENV.fetch("ALLOWED_HOSTS", nil))
    hosts = raw.to_s.split(",").map(&:strip).reject(&:empty?)
    return nil if hosts.empty? # keep Sinatra's secure default
    return { permitted_hosts: [] } if hosts.include?("*") # [] == allow any host

    # Mirror Sinatra's localhost defaults so adding hosts never removes access.
    base = ["localhost", ".localhost", ".test", IPAddr.new("0.0.0.0/0"), IPAddr.new("::/0")]
    { permitted_hosts: base + hosts }
  end

  host_authorization_options = host_authorization_config
  set :host_authorization, host_authorization_options if host_authorization_options

  helpers do
    def templates_dir
      dir = ENV["TEMPLATES_DIR"].to_s.strip
      return dir if !dir.empty? && Dir.exist?(dir) && any_templates?(dir)

      EXAMPLES_DIR
    end

    def any_templates?(dir)
      Dir.children(dir).any? { |f| f.end_with?(".liquid") }
    rescue SystemCallError
      false
    end

    def repo
      TemplateRepo.new(templates_dir)
    end

    def renderer
      Renderer.new(repo: repo, strict: truthy?(ENV.fetch("STRICT_VARIABLES", nil)))
    end

    def truthy?(val)
      %w[1 true yes on].include?(val.to_s.strip.downcase)
    end

    def raw?
      truthy?(params["_raw"]) || params["_raw"] == ""
    end

    # ?source=1 returns the composed, token-INTACT document (the per-theme .liquid you
    # upload to Auth0), as opposed to ?_raw=1 which returns the rendered output.
    def source?
      truthy?(params["source"]) || params["source"] == ""
    end

    def selected_theme
      EmailTheme.normalize(params["theme"])
    end

    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def query_overrides
      params.reject { |k, _| EXCLUDED_PARAMS.include?(k.to_s) }
    end

    # POST body: a raw JSON object (Content-Type application/json) or a "context"
    # form field (the render page's textarea). Returns [overrides_hash, error_string].
    def post_overrides
      source = request.media_type == "application/json" ? request.body.read : params["context"]
      return [{}, nil] if source.nil? || source.strip.empty?

      parsed = JSON.parse(source)
      parsed.is_a?(Hash) ? [parsed, nil] : [{}, "JSON body must be an object."]
    rescue JSON::ParserError => e
      [{}, "Invalid JSON: #{e.message}"]
    end

    def plain(body)
      content_type "text/plain"
      body
    end
  end

  get "/" do
    current = repo
    @entries = current.entries
    @group_order = GROUP_ORDER
    @themes = EmailTheme::THEME_ORDER.map { |k| { "key" => k, "label" => EmailTheme::THEMES[k][:label] } }
    # Per-template fixture variables (sans _meta) power the live Variáveis editor.
    @fixture_vars = current.names.to_h { |n| [n, current.fixture(n)["vars"]] }
    erb :"index.html"
  end

  get "/render/:name" do
    serve(params[:name], query_overrides)
  end

  post "/render/:name" do
    overrides, error = post_overrides
    serve(params[:name], overrides, pre_error: error)
  end

  # Email-client chrome for the previewer: the Liquid-rendered subject + derived
  # sender + recipient. Kept in app.rb (the renderer does the Liquid; this is routing).
  get "/api/meta/:name" do
    api_meta(params[:name], query_overrides)
  end

  post "/api/meta/:name" do
    overrides, _error = post_overrides
    api_meta(params[:name], overrides)
  end

  # Safety net: never emit a blank 200 — surface unexpected errors as a visible 500.
  error do
    status 500
    plain("Internal error: #{env["sinatra.error"]&.message}")
  end

  private

  # Renders one template into the bare composed email document (the previewer iframe's
  # body). ?source=1 returns the uploadable token-intact source; ?_raw=1 the rendered
  # output as text/plain; a Liquid error becomes a visible 422 page, never a blank 200.
  def serve(name, overrides, pre_error: nil)
    return render_not_found(name) unless repo.exist?(name)

    theme = selected_theme
    return plain(EmailTheme.compose_source(theme, repo.source(name))) if source?

    if pre_error
      status 422
      return raw? ? plain(pre_error) : error_page(pre_error)
    end

    begin
      output = renderer.render(name, overrides: overrides, theme: theme)
    rescue Liquid::Error => e
      status 422
      message = "Liquid error: #{e.message}"
      return raw? ? plain(message) : error_page(message)
    end

    return plain(output) if raw?

    content_type "text/html"
    output
  end

  def api_meta(name, overrides)
    return json_error(404, "Unknown template: #{name}") unless repo.exist?(name)

    sender = renderer.sender_for(name, overrides: overrides)
    json_response(
      subject: subject_for(name, overrides),
      from_name: sender[:name],
      from_addr: sender[:addr],
      to: email_for(name, overrides)
    )
  end

  # The subject is itself Liquid; under strict mode a missing var would raise, so fall
  # back to the unrendered subject string rather than 500 the chrome endpoint.
  def subject_for(name, overrides)
    renderer.render_subject(name, overrides: overrides)
  rescue Liquid::Error
    repo.fixture(name)["meta"]["subject"].to_s
  end

  def email_for(name, overrides)
    user = renderer.context_for(name, overrides: overrides)["user"]
    user.is_a?(Hash) ? user["email"].to_s : ""
  end

  def json_response(hash)
    content_type "application/json"
    JSON.generate(hash)
  end

  def json_error(code, message)
    status code
    json_response(error: message)
  end

  # A standalone HTML document so a render error is visible inside the previewer iframe.
  def error_page(message)
    content_type "text/html"
    <<~HTML
      <!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Erro de renderização</title></head>
      <body style="margin:0;padding:20px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;color:#a40000;background:#fff;white-space:pre-wrap;word-break:break-word">#{h(message)}</body></html>
    HTML
  end

  def render_not_found(name)
    status 404
    names = repo.names
    return plain("Unknown template: #{name}\nAvailable templates: #{names.join(", ")}") if raw?

    @name = name
    @names = names
    content_type "text/html"
    not_found_page
  end

  def not_found_page
    items = @names.map { |n| %(<li><a href="/render/#{h(n)}">#{h(n)}</a></li>) }.join
    <<~HTML
      <!doctype html><meta charset="utf-8"><title>Not found</title>
      <body style="font-family:system-ui,sans-serif;max-width:48rem;margin:3rem auto;padding:0 1rem">
        <p><a href="/">&larr; All templates</a></p>
        <h1>Unknown template: #{h(@name)}</h1>
        <p>Available templates:</p>
        <ul>#{items}</ul>
      </body>
    HTML
  end
end
