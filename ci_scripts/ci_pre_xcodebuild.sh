#!/bin/sh
# Xcode Cloud: generate CloudflareSecrets.plist from environment variables.
# Set CF_ACCOUNT_ID and CF_AUTH_TOKEN as secrets in your workflow's Environment section.

set -e

if [ -n "$CI_XCODE_CLOUD" ] && [ -n "$CF_ACCOUNT_ID" ] && [ -n "$CF_AUTH_TOKEN" ]; then
  REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-.}"
  PLIST_PATH="$REPO_ROOT/TechQTA/Config/CloudflareSecrets.plist"
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
  echo "Generated CloudflareSecrets.plist from environment variables"
fi

exit 0
