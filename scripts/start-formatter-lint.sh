#!/usr/bin/env sh
set -e

bundle install

# Format in place, then lint-gate. CI runs the gate step only (no autocorrect),
# so the job fails on offenses instead of silently rewriting files.
bundle exec rubocop --autocorrect-all
exec bundle exec rubocop
