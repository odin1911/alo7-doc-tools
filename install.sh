#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

install_codex() {
  command -v codex >/dev/null 2>&1 || {
    printf '%s\n' '未找到 codex 命令。' >&2
    exit 1
  }

  command -v npx >/dev/null 2>&1 || {
    printf '%s\n' '未找到 npx，请先安装 Node.js/npm。' >&2
    exit 1
  }

  codex plugin marketplace add "$REPO_ROOT"
  codex plugin add alo7-doc-tools@alo7-doc-tools

  printf '%s\n' 'ALO7 Doc Tools 已安装到 Codex；请新建任务以加载插件。'
}

case "${1:-codex}" in
  codex)
    install_codex
    ;;
  opencode)
    bash "$REPO_ROOT/scripts/install-opencode.sh"
    ;;
  all)
    install_codex
    bash "$REPO_ROOT/scripts/install-opencode.sh"
    ;;
  *)
    printf '用法：%s [codex|opencode|all]\n' "$0" >&2
    exit 2
    ;;
esac
