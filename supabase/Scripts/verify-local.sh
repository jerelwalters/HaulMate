#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

export SUPABASE_TELEMETRY_DISABLED="${SUPABASE_TELEMETRY_DISABLED:-1}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop, then run supabase start." >&2
  exit 1
fi

if ! supabase status >/dev/null 2>&1; then
  echo "Local Supabase is not running. Start it with: supabase start" >&2
  exit 1
fi

supabase db reset --local
supabase migration list --local
supabase db advisors --local --type security --level warn --fail-on error
supabase db query --local --output table \
  "select current_database() as database_name, current_schema() as schema_name, current_setting('server_version') as server_version;"
