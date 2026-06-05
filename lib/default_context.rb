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
      "inviter" => { "name" => "Acme Admin" },
      "organization" => { "name" => "acme", "display_name" => "Acme Inc." },
      "prompt" => { "name" => "login" },
      "locale" => "en"
    }
  end
end
