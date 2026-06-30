#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

export SUPABASE_TELEMETRY_DISABLED="${SUPABASE_TELEMETRY_DISABLED:-1}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required for local auth verification." >&2
    exit 1
  fi
}

status_value() {
  local name="$1"
  printf '%s\n' "$STATUS_ENV" | awk -F= -v key="$name" '$1 == key { gsub(/^"|"$/, "", $2); print $2 }'
}

request_json() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local output_file="$4"

  if [[ -n "$body" ]]; then
    curl --fail --silent --show-error \
      --request "$method" \
      --header "apikey: $PUBLIC_KEY" \
      --header "Content-Type: application/json" \
      --data "$body" \
      "$url" > "$output_file"
  else
    curl --fail --silent --show-error \
      --request "$method" \
      --header "apikey: $PUBLIC_KEY" \
      "$url" > "$output_file"
  fi
}

require_command curl
require_command docker
require_command jq
require_command supabase

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop, then run supabase start." >&2
  exit 1
fi

if ! supabase status >/dev/null 2>&1; then
  echo "Local Supabase is not running. Start it with: supabase start" >&2
  exit 1
fi

STATUS_ENV="$(supabase status -o env 2>/dev/null)"
API_URL="$(status_value API_URL)"
PUBLIC_KEY="$(status_value PUBLISHABLE_KEY)"
MAIL_URL="$(status_value MAILPIT_URL)"

if [[ -z "$PUBLIC_KEY" ]]; then
  PUBLIC_KEY="$(status_value ANON_KEY)"
fi

if [[ -z "$MAIL_URL" ]]; then
  MAIL_URL="$(status_value INBUCKET_URL)"
fi

if [[ -z "$API_URL" || -z "$PUBLIC_KEY" || -z "$MAIL_URL" ]]; then
  echo "Could not read API URL, public key, or local mail URL from supabase status." >&2
  exit 1
fi

EMAIL="auth-smoke-$(date +%s)@haulmate.local"
PASSWORD="HaulMate123"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Checking local Auth health..."
curl --fail --silent --show-error \
  --header "apikey: $PUBLIC_KEY" \
  "$API_URL/auth/v1/health" >/dev/null

echo "Creating local Auth user..."
request_json POST "$API_URL/auth/v1/signup" \
  "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  "$TMP_DIR/signup.json"
jq -e '.user.id and .user.email' "$TMP_DIR/signup.json" >/dev/null

echo "Signing in with password..."
request_json POST "$API_URL/auth/v1/token?grant_type=password" \
  "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  "$TMP_DIR/signin.json"
jq -e '.access_token and .refresh_token and .user.id' "$TMP_DIR/signin.json" >/dev/null

REFRESH_TOKEN="$(jq -r '.refresh_token' "$TMP_DIR/signin.json")"

echo "Refreshing session..."
request_json POST "$API_URL/auth/v1/token?grant_type=refresh_token" \
  "{\"refresh_token\":\"$REFRESH_TOKEN\"}" \
  "$TMP_DIR/refresh.json"
jq -e '.access_token and .refresh_token and .user.id' "$TMP_DIR/refresh.json" >/dev/null

ACCESS_TOKEN="$(jq -r '.access_token' "$TMP_DIR/refresh.json")"

echo "Signing out..."
curl --fail --silent --show-error \
  --request POST \
  --header "apikey: $PUBLIC_KEY" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  "$API_URL/auth/v1/logout" >/dev/null

echo "Requesting password reset email..."
request_json POST "$API_URL/auth/v1/recover" \
  "{\"email\":\"$EMAIL\"}" \
  "$TMP_DIR/recover.json"

echo "Checking local mail catcher for reset email..."
for _ in {1..10}; do
  if curl --fail --silent --show-error "$MAIL_URL/api/v1/messages" \
    | jq -e --arg email "$EMAIL" '
      [.messages[]?
        | select(
          any(.To[]?; ((.Address? // .address? // "") == $email))
          and ((.Subject // "") | test("reset"; "i"))
        )
      ] | length > 0
    ' >/dev/null; then
    echo "Local auth smoke check passed for $EMAIL."
    exit 0
  fi

  sleep 1
done

echo "Password reset email was not found in the local mail catcher." >&2
exit 1
