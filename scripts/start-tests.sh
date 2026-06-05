#!/usr/bin/env sh
set -e

bundle install

exec bundle exec rake test
