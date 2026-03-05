#!/bin/sh
# Generate CloudflareSecrets.plist from .env (for local development).
# Run from project root: ./scripts/generate_secrets_from_env.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
PLIST_PATH="$REPO_ROOT/TechQTA/Config/CloudflareSecrets.plist"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found. Copy .env.example to .env and add your credentials."
  exit 1
fi

# Simple .env parser (handles KEY=value, ignores comments and empty lines)
CF_ACCOUNT_ID=""
CF_AUTH_TOKEN=""
while IFS= read -r line; do
  case "$line" in
    CF_ACCOUNT_ID=*) CF_ACCOUNT_ID="${line#*=}";;
    CF_AUTH_TOKEN=*) CF_AUTH_TOKEN="${line#*=}";;
  esac
done < "$ENV_FILE"

# Trim whitespace
CF_ACCOUNT_ID=$(echo "$CF_ACCOUNT_ID" | xargs)
CF_AUTH_TOKEN=$(echo "$CF_AUTH_TOKEN" | xargs)

if [ -z "$CF_ACCOUNT_ID" ] || [ -z "$CF_AUTH_TOKEN" ] || [ "$CF_ACCOUNT_ID" = "your_account_id" ] || [ "$CF_AUTH_TOKEN" = "your_auth_token" ]; then
  echo "Set CF_ACCOUNT_ID and CF_AUTH_TOKEN in .env"
  exit 1
fi

mkdir -p "$(dirname "$PLIST_PATH")"
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFAccountID</key>
	<string>$CF_ACCOUNT_ID</string>
	<key>CFAuthToken</key>
	<string>$CF_AUTH_TOKEN</string>
</dict>
</plist>
EOF
echo "Generated CloudflareSecrets.plist from .env"
