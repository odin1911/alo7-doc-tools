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
ln -s "$TEST_SCRIPT" "$TEST_TMP/bin/security"
TEST_PATH="$TEST_TMP/bin:/usr/bin:/bin"

CONFLUENCE="$TEST_ROOT/skills/fetch-confluence/scripts/fetch-confluence.sh"
REDMINE="$TEST_ROOT/skills/fetch-redmine/scripts/fetch-redmine.sh"

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

bash -n "$CONFLUENCE" || fail "invalid Confluence script syntax"
bash -n "$REDMINE" || fail "invalid Redmine script syntax"

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

printf 'PASS: fetch-confluence and fetch-redmine\n'
