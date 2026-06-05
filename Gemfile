# frozen_string_literal: true

source "https://rubygems.org"

# Runtime: keep this list tiny on purpose (see .claude/rules/main-rules.md).
gem "liquid", "~> 5.12"  # Shopify Liquid — Auth0's email/page dialect
gem "puma"               # Rack app server Sinatra 4 expects (WEBrick no longer bundled)
gem "sinatra", "~> 4.2"  # >= 4.2.1 fixes the ETag ReDoS CVE-2025-61921

group :development, :test do
  gem "minitest", "~> 6.0" # bundled gem, but must be declared under Bundler
  gem "rake"
  gem "rubocop", require: false
end
