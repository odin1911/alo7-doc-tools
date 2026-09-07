#!/bin/bash
set -euo pipefail

if ! command -v npx >/dev/null 2>&1; then
  ALO7_NVM_SCRIPT="${NVM_DIR:-${HOME}/.nvm}/nvm.sh"
  if [[ -s "$ALO7_NVM_SCRIPT" ]]; then
    set +u
    source "$ALO7_NVM_SCRIPT"
    set -u
  fi
fi

command -v npx >/dev/null 2>&1 || {
  printf '%s\n' 'Redmine MCP 启动失败：未找到 npx。' >&2
  exit 1
}

exec npx "$@"
