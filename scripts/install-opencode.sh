#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/alo7-doc-tools"
GLOBAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ASSET_DIR="${ALO7_OPENCODE_CONFIG_DIR:-${OPENCODE_CONFIG_DIR:-$GLOBAL_CONFIG_DIR}}"
TOOLS_DIR="$ASSET_DIR/alo7-doc-tools"

for command_name in opencode npx; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf '未找到 %s 命令。\n' "$command_name" >&2
    exit 1
  }
done

install -d "$ASSET_DIR/skills" "$ASSET_DIR/plugins" "$TOOLS_DIR"
for skill_name in redmine fetch-confluence; do
  install -d "$ASSET_DIR/skills/$skill_name"
  cp -R "$PLUGIN_ROOT/skills/$skill_name/." "$ASSET_DIR/skills/$skill_name/"
done
install -m 0755 "$PLUGIN_ROOT/scripts/redmine-mcp.sh" "$TOOLS_DIR/redmine-mcp.sh"
install -m 0644 "$PLUGIN_ROOT/opencode/alo7-doc-tools.js" "$ASSET_DIR/plugins/alo7-doc-tools.js"

printf '%s\n' 'ALO7 Doc Tools 已安装到 OpenCode；请重启 OpenCode。'
