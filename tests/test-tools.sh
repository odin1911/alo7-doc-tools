#!/bin/bash
set -euo pipefail

fake_curl() {
  local output=""
  local args=" $* "
  local config
  config="$(cat)"

  [[ "${1:-}" == "-q" ]] || exit 3

  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-o" ]]; then
      output="$2"
      shift 2
    else
      shift
    fi
  done

  [[ "${FAKE_CURL_FAIL:-0}" != 1 ]] || exit 22
  [[ "$args" != *"${EXPECTED_CREDENTIAL:-}"* ]] || exit 3

  case "${FAKE_SERVICE:-}" in
    confluence)
      [[ "$config" == *"Authorization: Bearer ${EXPECTED_CREDENTIAL}"* ]] || exit 3
      [[ "$args" == *"https://confluence.alo7.cn/rest/api/content/123?expand=body.view "* ]] ||
        exit 3
      printf '%s\n' '{"body":{"view":{"value":"<p>ok</p>"}}}'
      ;;
    redmine)
      [[ "$config" == *"X-Redmine-API-Key: ${EXPECTED_CREDENTIAL}"* ]] || exit 3
      [[ "$args" == *"https://redmine.saybot.net/issues/456.json?include=journals,attachments,relations "* ]] ||
        exit 3
      printf '%s\n' '{"issue":{"id":456,"journals":[],"attachments":[]}}' > "$output"
      ;;
    *)
      exit 2
      ;;
  esac
}

case "${0##*/}" in
  curl)
    fake_curl "$@"
    exit
    ;;
  codex)
    printf '%s\n' "$*" >> "$CODEX_CALL_LOG"
    exit
    ;;
  npx)
    if [[ -n "${NPX_CALL_LOG:-}" ]]; then
      printf '%s\n' "$*" >> "$NPX_CALL_LOG"
    fi
    exit
    ;;
  opencode)
    exit
    ;;
  security)
    if [[ -n "${EXPECTED_KEYCHAIN_ACCOUNT:-}" ]]; then
      [[ " $* " == *" -a ${EXPECTED_KEYCHAIN_ACCOUNT} "* ]] || exit 3
    fi
    if [[ -n "${EXPECTED_KEYCHAIN_SERVICE:-}" ]]; then
      [[ " $* " == *" -s ${EXPECTED_KEYCHAIN_SERVICE} "* ]] || exit 3
    fi
    [[ -n "${FAKE_KEYCHAIN_VALUE:-}" ]] || exit 1
    printf '%s\n' "$FAKE_KEYCHAIN_VALUE"
    exit
    ;;
esac

TEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_SCRIPT="$TEST_ROOT/tests/${0##*/}"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/alo7-doc-tools-test.XXXXXX")"
trap 'rm -rf -- "$TEST_TMP"' EXIT
mkdir "$TEST_TMP/bin"
ln -s "$TEST_SCRIPT" "$TEST_TMP/bin/curl"
ln -s "$TEST_SCRIPT" "$TEST_TMP/bin/codex"
ln -s "$TEST_SCRIPT" "$TEST_TMP/bin/npx"
ln -s "$TEST_SCRIPT" "$TEST_TMP/bin/opencode"
ln -s "$TEST_SCRIPT" "$TEST_TMP/bin/security"
TEST_PATH="$TEST_TMP/bin:/usr/bin:/bin"

PLUGIN_ROOT="$TEST_ROOT/plugins/alo7-doc-tools"
CONFLUENCE="$PLUGIN_ROOT/skills/fetch-confluence/scripts/fetch-confluence.sh"
REDMINE="$TEST_ROOT/legacy/fetch-redmine/scripts/fetch-redmine.sh"
CONFLUENCE_SKILL="$PLUGIN_ROOT/skills/fetch-confluence/SKILL.md"
REDMINE_SKILL="$TEST_ROOT/legacy/fetch-redmine/SKILL.md.bak"
REDMINE_MCP_SKILL="$PLUGIN_ROOT/skills/redmine/SKILL.md"
MCP_CONFIG="$PLUGIN_ROOT/.mcp.json"
MCP_LAUNCHER="$PLUGIN_ROOT/scripts/redmine-mcp.sh"
INSTALLER="$TEST_ROOT/install.sh"
OPENCODE_INSTALLER="$TEST_ROOT/scripts/install-opencode.sh"
OPENCODE_PLUGIN="$PLUGIN_ROOT/opencode/alo7-doc-tools.js"

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

assert_equal() {
  [[ "$1" == "$2" ]] || fail "expected '$1', got '$2'"
}

assert_exit() {
  local expected="$1"
  shift
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || {
    printf 'expected exit %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  }
}

assert_failure() {
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  [[ "$actual" -ne 0 ]] || {
    printf 'expected failure: %s\n' "$*" >&2
    exit 1
  }
}

assert_skill_refresh_policy() {
  local skill="$1"
  grep -F 'For a new task, fetch and analyze the document once before using it as evidence.' "$skill" >/dev/null ||
    fail "$skill does not fetch once per task"
  grep -F 'By default, reuse information already extracted in the current task; do not fetch again or repeat the analysis.' "$skill" >/dev/null ||
    fail "$skill does not reuse current-task context"
  grep -F 'Reread the same saved output only when context compression or an exact check makes it necessary; this is not a refresh.' "$skill" >/dev/null ||
    fail "$skill does not allow necessary local rereads"
  grep -F 'Fetch again only when the user explicitly asks to refresh.' "$skill" >/dev/null ||
    fail "$skill does not limit refreshes"
  grep -F 'Delete default temporary output after its final read; keep output paths explicitly requested by the user.' "$skill" >/dev/null ||
    fail "$skill does not define output cleanup"
}

bash -n "$CONFLUENCE" || fail "invalid Confluence script syntax"
bash -n "$REDMINE" || fail "invalid Redmine script syntax"
bash -n "$MCP_LAUNCHER" || fail "invalid Redmine MCP launcher syntax"
bash -n "$INSTALLER" || fail "invalid installer syntax"
bash -n "$OPENCODE_INSTALLER" || fail "invalid OpenCode installer syntax"
node --check "$OPENCODE_PLUGIN" || fail "invalid OpenCode plugin syntax"
grep -F 'bash scripts/fetch-confluence.sh <pageId> [output.html]' "$CONFLUENCE_SKILL" >/dev/null ||
  fail "Confluence Skill does not invoke its script with Bash"
grep -F 'bash scripts/fetch-redmine.sh <issue-id> [output.json]' "$REDMINE_SKILL" >/dev/null ||
  fail "Redmine Skill does not invoke its script with Bash"
assert_skill_refresh_policy "$CONFLUENCE_SKILL"
assert_skill_refresh_policy "$REDMINE_SKILL"
grep -F 'Do not open the issue with a browser before checking the MCP tools.' "$REDMINE_MCP_SKILL" >/dev/null ||
  fail "Redmine MCP Skill does not prefer MCP"
jq -e '.mcpServers["alo7-redmine"].args == ["./scripts/redmine-mcp.sh", "-y", "@thelabnyc/redmine-mcp@0.5.0"]' "$MCP_CONFIG" >/dev/null ||
  fail "Redmine MCP package is not pinned"
jq -e '.mcpServers["alo7-redmine"].enabled_tools | index("get-issue") and index("download-attachment") and index("update-issue")' "$MCP_CONFIG" >/dev/null ||
  fail "Required Redmine MCP tools are not enabled"
jq -e '.mcpServers["alo7-redmine"].env.REDMINE_URL == "https://redmine.saybot.net"' "$MCP_CONFIG" >/dev/null ||
  fail "Redmine URL is not configured"
jq -e '.mcpServers["alo7-redmine"].env_vars == ["REDMINE_API_KEY"]' "$MCP_CONFIG" >/dev/null ||
  fail "Redmine API key is not inherited from the environment"
jq -e '.mcpServers["alo7-redmine"].command == "/bin/bash"' "$MCP_CONFIG" >/dev/null ||
  fail "Redmine MCP launcher is not configured"

NPX_CALL_LOG="$TEST_TMP/npx-calls.log" PATH="$TEST_PATH" bash "$MCP_LAUNCHER" -y @thelabnyc/redmine-mcp@0.5.0
assert_equal '-y @thelabnyc/redmine-mcp@0.5.0' "$(< "$TEST_TMP/npx-calls.log")"

CODEX_CALL_LOG="$TEST_TMP/codex-calls.log" PATH="$TEST_PATH" bash "$INSTALLER" >/dev/null
assert_equal "plugin marketplace add $TEST_ROOT
plugin add alo7-doc-tools@alo7-doc-tools" "$(< "$TEST_TMP/codex-calls.log")"

OPENCODE_ASSET_DIR="$TEST_TMP/opencode-assets"
mkdir -p "$OPENCODE_ASSET_DIR"
printf '%s\n' '{' '  // keep this comment' '  "$schema": "https://opencode.ai/config.json"' '}' \
  > "$OPENCODE_ASSET_DIR/opencode.jsonc"
OPENCODE_CONFIG_BEFORE="$(< "$OPENCODE_ASSET_DIR/opencode.jsonc")"
OPENCODE_CONFIG_DIR="$OPENCODE_ASSET_DIR" PATH="$TEST_PATH" bash "$INSTALLER" opencode >/dev/null
assert_equal "$OPENCODE_CONFIG_BEFORE" "$(< "$OPENCODE_ASSET_DIR/opencode.jsonc")"
[[ -f "$OPENCODE_ASSET_DIR/skills/redmine/SKILL.md" ]] || fail "Redmine skill was not installed for OpenCode"
[[ -f "$OPENCODE_ASSET_DIR/skills/fetch-confluence/SKILL.md" ]] || fail "Confluence skill was not installed for OpenCode"
[[ -x "$OPENCODE_ASSET_DIR/alo7-doc-tools/redmine-mcp.sh" ]] || fail "OpenCode MCP launcher is not executable"
[[ -f "$OPENCODE_ASSET_DIR/plugins/alo7-doc-tools.js" ]] || fail "OpenCode plugin was not installed"
grep -F '@thelabnyc/redmine-mcp@0.5.0' "$OPENCODE_ASSET_DIR/plugins/alo7-doc-tools.js" >/dev/null ||
  fail "OpenCode plugin does not pin the Redmine MCP package"
grep -F 'REDMINE_API_KEY: "{env:REDMINE_API_KEY}"' "$OPENCODE_ASSET_DIR/plugins/alo7-doc-tools.js" >/dev/null ||
  fail "OpenCode plugin does not read the API key from the environment"

assert_exit 2 bash "$CONFLUENCE" invalid
assert_exit 2 bash "$REDMINE" invalid
assert_exit 1 env -u CONFLUENCE_PAT PATH="$TEST_PATH" bash "$CONFLUENCE" 123
assert_exit 1 env -u REDMINE_API_KEY PATH="$TEST_PATH" bash "$REDMINE" 456

PATH="$TEST_PATH" FAKE_SERVICE=confluence EXPECTED_CREDENTIAL=test-confluence-token \
  CONFLUENCE_PAT=test-confluence-token \
  CONFLUENCE_BASE_URL=https://confluence.example.test \
  bash "$CONFLUENCE" 123 "$TEST_TMP/custom-confluence.html" >/dev/null
PATH="$TEST_PATH" FAKE_SERVICE=redmine EXPECTED_CREDENTIAL=test-redmine-key \
  REDMINE_API_KEY=test-redmine-key REDMINE_BASE_URL=https://redmine.example.test \
  bash "$REDMINE" 456 "$TEST_TMP/custom-redmine.json" >/dev/null

CONFLUENCE_OUTPUT="$TEST_TMP/confluence output.html"
PATH="$TEST_PATH" FAKE_SERVICE=confluence EXPECTED_CREDENTIAL=test-confluence-token \
  FAKE_KEYCHAIN_VALUE=wrong CONFLUENCE_PAT=test-confluence-token \
  bash "$CONFLUENCE" 123 "$CONFLUENCE_OUTPUT" >/dev/null
assert_equal "<p>ok</p>" "$(< "$CONFLUENCE_OUTPUT")"

REDMINE_OUTPUT="$TEST_TMP/redmine output.json"
PATH="$TEST_PATH" FAKE_SERVICE=redmine EXPECTED_CREDENTIAL=test-redmine-key \
  FAKE_KEYCHAIN_VALUE=wrong REDMINE_API_KEY=test-redmine-key \
  bash "$REDMINE" 456 "$REDMINE_OUTPUT" >/dev/null
jq -e '.issue.id == 456' "$REDMINE_OUTPUT" >/dev/null || fail "wrong Redmine issue ID"

env -u CONFLUENCE_PAT PATH="$TEST_PATH" FAKE_SERVICE=confluence \
  EXPECTED_CREDENTIAL=keychain-confluence FAKE_KEYCHAIN_VALUE=keychain-confluence \
  EXPECTED_KEYCHAIN_ACCOUNT="$(id -un)" EXPECTED_KEYCHAIN_SERVICE=alo7-confluence-pat \
  CONFLUENCE_ACCOUNT=wrong CONFLUENCE_KEYCHAIN_SERVICE=wrong \
  bash "$CONFLUENCE" 123 "$CONFLUENCE_OUTPUT" >/dev/null
env -u REDMINE_API_KEY PATH="$TEST_PATH" FAKE_SERVICE=redmine \
  EXPECTED_CREDENTIAL=keychain-redmine FAKE_KEYCHAIN_VALUE=keychain-redmine \
  EXPECTED_KEYCHAIN_ACCOUNT="$(id -un)" EXPECTED_KEYCHAIN_SERVICE=alo7-redmine-api-key \
  REDMINE_ACCOUNT=wrong REDMINE_KEYCHAIN_SERVICE=wrong \
  bash "$REDMINE" 456 "$REDMINE_OUTPUT" >/dev/null

VICTIM="$TEST_TMP/victim"
CONFLUENCE_LINK="$TEST_TMP/confluence-link.html"
printf 'keep\n' > "$VICTIM"
ln -s "$VICTIM" "$CONFLUENCE_LINK"
PATH="$TEST_PATH" FAKE_SERVICE=confluence EXPECTED_CREDENTIAL=test-confluence-token \
  CONFLUENCE_PAT=test-confluence-token bash "$CONFLUENCE" 123 "$CONFLUENCE_LINK" >/dev/null
assert_equal "keep" "$(< "$VICTIM")"
[[ ! -L "$CONFLUENCE_LINK" ]] || fail "Confluence output remained a symlink"

CONFLUENCE_DEFAULT_1="$(
  TMPDIR="$TEST_TMP" PATH="$TEST_PATH" FAKE_SERVICE=confluence \
    EXPECTED_CREDENTIAL=test-confluence-token CONFLUENCE_PAT=test-confluence-token \
    bash "$CONFLUENCE" 123
)"
CONFLUENCE_DEFAULT_2="$(
  TMPDIR="$TEST_TMP" PATH="$TEST_PATH" FAKE_SERVICE=confluence \
    EXPECTED_CREDENTIAL=test-confluence-token CONFLUENCE_PAT=test-confluence-token \
    bash "$CONFLUENCE" 123
)"
[[ "$CONFLUENCE_DEFAULT_1" != "$CONFLUENCE_DEFAULT_2" ]] ||
  fail "Confluence default output path is not unique"

REDMINE_DEFAULT_1="$(
  TMPDIR="$TEST_TMP" PATH="$TEST_PATH" FAKE_SERVICE=redmine \
    EXPECTED_CREDENTIAL=test-redmine-key REDMINE_API_KEY=test-redmine-key \
    bash "$REDMINE" 456
)"
REDMINE_DEFAULT_2="$(
  TMPDIR="$TEST_TMP" PATH="$TEST_PATH" FAKE_SERVICE=redmine \
    EXPECTED_CREDENTIAL=test-redmine-key REDMINE_API_KEY=test-redmine-key \
    bash "$REDMINE" 456
)"
[[ "$REDMINE_DEFAULT_1" != "$REDMINE_DEFAULT_2" ]] ||
  fail "Redmine default output path is not unique"

printf 'keep\n' > "$CONFLUENCE_OUTPUT"
assert_failure env PATH="$TEST_PATH" FAKE_SERVICE=confluence FAKE_CURL_FAIL=1 \
  EXPECTED_CREDENTIAL=test-confluence-token CONFLUENCE_PAT=test-confluence-token \
  bash "$CONFLUENCE" 123 "$CONFLUENCE_OUTPUT"
assert_equal "keep" "$(< "$CONFLUENCE_OUTPUT")"

printf 'keep\n' > "$REDMINE_OUTPUT"
assert_failure env PATH="$TEST_PATH" FAKE_SERVICE=redmine FAKE_CURL_FAIL=1 \
  EXPECTED_CREDENTIAL=test-redmine-key REDMINE_API_KEY=test-redmine-key \
  bash "$REDMINE" 456 "$REDMINE_OUTPUT"
assert_equal "keep" "$(< "$REDMINE_OUTPUT")"

printf 'PASS: alo7-doc-tools plugin and legacy fetch tools\n'
