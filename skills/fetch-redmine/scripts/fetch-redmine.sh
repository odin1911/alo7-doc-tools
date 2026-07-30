#!/bin/bash
set -euo pipefail

BASE_URL="${REDMINE_BASE_URL:-https://redmine.saybot.net}"
ISSUE_ID="${1:-}"
OUTPUT="${2:-}"
ACCOUNT="${REDMINE_ACCOUNT:-$(id -un)}"
KEYCHAIN_SERVICE="${REDMINE_KEYCHAIN_SERVICE:-alo7-redmine-api-key}"

if ! [[ "$ISSUE_ID" =~ ^[0-9]+$ ]]; then
  echo "用法: $0 <issue-id> [output.json]" >&2
  exit 2
fi

TEMP_DIR="${TMPDIR:-/tmp}"
OUTPUT="${OUTPUT:-${TEMP_DIR%/}/redmine-${ISSUE_ID}.json}"

API_KEY="${REDMINE_API_KEY:-}"
if [[ -z "$API_KEY" ]] && command -v security >/dev/null 2>&1; then
  API_KEY="$(
    security find-generic-password \
      -a "$ACCOUNT" \
      -s "$KEYCHAIN_SERVICE" \
      -w 2>/dev/null || true
  )"
fi

if [[ -z "$API_KEY" ]]; then
  echo "未找到 Redmine API Key，请写入 macOS 钥匙串或设置 REDMINE_API_KEY" >&2
  exit 1
fi

RAW_FILE="$(mktemp "${TEMP_DIR%/}/redmine-${ISSUE_ID}.raw.XXXXXX")"
JSON_FILE="$(mktemp "${TEMP_DIR%/}/redmine-${ISSUE_ID}.json.XXXXXX")"
cleanup() {
  rm -f -- "$RAW_FILE" "$JSON_FILE"
}
trap cleanup EXIT

printf 'header = "X-Redmine-API-Key: %s"\n' "$API_KEY" |
  curl -fsS \
    --config - \
    -H "Accept: application/json" \
    "${BASE_URL%/}/issues/${ISSUE_ID}.json?include=journals,attachments,relations" \
    -o "$RAW_FILE"

jq -e . "$RAW_FILE" > "$JSON_FILE"
mv "$JSON_FILE" "$OUTPUT"
printf '已保存到: %s\n' "$OUTPUT"
