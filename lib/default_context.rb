# frozen_string_literal: true

# Built-in, Auth0-shaped default variables so ANY template renders something even
# without a fixture. Brand-neutral on purpose ("Acme", example.com) — real branding
# lives in the consumer repo. Keys are strings because that is what Liquid resolves
# against (fixtures come from JSON and query params, both string-keyed too).
#
# This is the lowest layer of the merge order:
#   defaults < _fixtures/<name>.json < per-request overrides.
module DefaultContext
  module_function

  def call
    {
      "application" => {
        "name" => "Acme",
        "logo_uri" => "https://example.com/logo.png",
        "clientID" => "acme-client-id"
      },
      "user" => {
        "email" => "user@example.com",
        "name" => "Acme User",
        "given_name" => "Acme",
        "family_name" => "User",
        "user_metadata" => { "preferredLanguage" => "en" },
        "app_metadata" => {}
      },
      # New Universal Login page-template branding. `logo_url` empty by default so the
      # injected widget shows its monogram; set it (or organization.branding.logo_url,
      # which takes precedence) to preview a real logo-bearing widget. Brand-neutral.
      "branding" => {
        "logo_url" => "",
        "colors" => { "primary" => "#15151a", "page_background" => "#ffffff" }
      },
      "friendly_name" => "Acme",
      "tenant" => "acme",
      "url" => "https://example.com/action?ticket=ABC123",
      "code" => "ACME01",
      "link" => "https://example.com/enroll?ticket=ABC123",
      "password" => "",
      "support_url" => "https://example.com/support",
      "request_language" => "en",
      "operating_system" => "macOS",
      "connection" => "Username-Password-Authentication",
      "connection_id" => "con_acme",
      # Tenant custom error page (error_page.html) surface. Auth0 supplies exactly these
      # top-level variables to that template: client_id, connection (above), lang, error
      # (an OAuth error CODE string), error_description, tracking (an internal-log id).
      # `show_log_link`/`url` are page CONFIG, not template context, so they are not here.
      # Defaulted to a representative scenario so an error template renders something even
      # without a fixture; brand-neutral. See https://auth0.com/docs/customize/login-pages/custom-error-pages
      "client_id" => "acme-client-id",
      "lang" => "en",
      "error" => "access_denied",
      "error_description" => "You do not have permission to access this application.",
      "tracking" => "acme-tracking-id",
      "inviter" => { "name" => "Acme Admin" },
      # organization.branding.logo_url, when set, overrides tenant branding for the
      # widget logo (org-context login). Empty by default; brand-neutral.
      "organization" => {
        "name" => "acme",
        "display_name" => "Acme Inc.",
        "branding" => { "logo_url" => "" }
      },
      "prompt" => { "name" => "login" },
      "locale" => "en"
    }
  end
end
