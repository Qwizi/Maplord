#!/bin/bash
# Docker entrypoint init script — runs migrations and seeds before starting.
# Idempotent — safe to run on every container start.

set -e

echo "==> Running database migrations..."
uv run python manage.py migrate --noinput

echo "==> Loading game config (merge mode)..."
uv run python manage.py load_game_config --merge --skip-provinces

echo "==> Creating bot users..."
uv run python manage.py create_bots

echo "==> Setting up official gamenode..."
uv run python manage.py setup_official_gamenode

echo "==> Init complete, starting server..."
exec "$@"
