#!/usr/bin/env sh
set -e

bundle install

exec bundle exec puma config.ru -b "tcp://${BIND:-0.0.0.0}:${PORT:-9292}"
