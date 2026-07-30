#!/bin/bash
set -euo pipefail

PAGE_ID="${1:-}"
OUTPUT="${2:-}"

if ! [[ "$PAGE_ID" =~ ^[0-9]+$ ]]; then
  echo "用法: $0 <pageId> [output.html]" >&2
  exit 2
fi

TEMP_DIR="${TMPDIR:-/tmp}"

PAT="${CONFLUENCE_PAT:-}"
if [[ -z "$PAT" ]] && command -v security >/dev/null 2>&1; then
  PAT="$(
    security find-generic-password \
      -a "$(id -un)" \
      -s "alo7-confluence-pat" \
      -w 2>/dev/null || true
  )"
fi

if [[ -z "$PAT" ]]; then
  echo "未找到 Confluence PAT，请写入 macOS 钥匙串或设置 CONFLUENCE_PAT" >&2
  exit 1
fi

RESULT="$(
  printf 'header = "Authorization: Bearer %s"\n' "$PAT" |
    curl -q -fsS \
      --config - \
      -H "Accept: application/json" \
      "https://confluence.alo7.cn/rest/api/content/${PAGE_ID}?expand=body.view" |
    jq -er '.body.view.value'
)"

TEMP_FILE="$(mktemp "${TEMP_DIR%/}/confluence-${PAGE_ID}.html.XXXXXX")"
cleanup() {
  rm -f -- "$TEMP_FILE"
}
trap cleanup EXIT
printf '%s\n' "$RESULT" > "$TEMP_FILE"

if [[ -n "$OUTPUT" ]]; then
  mv "$TEMP_FILE" "$OUTPUT"
else
  OUTPUT="$TEMP_FILE"
fi
TEMP_FILE=""
printf '已保存到: %s\n' "$OUTPUT"
