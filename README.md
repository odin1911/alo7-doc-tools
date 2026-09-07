# ALO7 Doc Tools

ALO7 内部文档工具仓库，通过一次安装为 Codex 或 OpenCode 提供 Redmine MCP 与文档 Skills。

## 组件

| 组件 | 用途 | 实现 |
| --- | --- | --- |
| `redmine` | 读取、搜索和按授权修改 Redmine issue | `redmine-mcp-stdio@1.2.0` |
| `fetch-confluence` | 获取自建 Confluence 页面 | Skill + Bash/curl |

插件源码位于 `plugins/alo7-doc-tools/`。旧版 `fetch-redmine` shell 实现归档在
`legacy/fetch-redmine/`，不参与安装和自动发现。

## 安装

前置条件：本机已安装目标客户端和 Node.js/npm。插件启动器优先从 PATH 查找 `npx`，并兼容常见的 nvm 安装。
`REDMINE_API_KEY` 必须由环境变量提供，不得写入仓库。

仓库已克隆到本机时，按目标客户端执行：

```bash
./install.sh codex
./install.sh opencode
./install.sh all
```

不传参数时默认安装 Codex，保持旧用法兼容。`all` 会依次安装两个客户端。

也可以直接从 GitHub marketplace 安装：

```bash
codex plugin marketplace add odin1911/alo7-doc-tools
codex plugin add alo7-doc-tools@alo7-doc-tools
```

安装后新建 Codex 任务，使新 Skill 和 MCP 工具进入上下文。Redmine 写入工具保持调用前确认。

已有手工 `[mcp_servers.redmine]` 配置的机器，应先验证插件正常工作，再删除旧配置，避免加载两套 Redmine MCP。

OpenCode 安装器把 skills 和一个薄适配 plugin 放入 `~/.config/opencode/`。适配 plugin 只注册
`alo7-redmine`，不会修改或覆盖现有的 `opencode.json` / `opencode.jsonc`。

## 更新

```bash
codex plugin marketplace upgrade alo7-doc-tools
codex plugin add alo7-doc-tools@alo7-doc-tools
./install.sh opencode
```

## Confluence 凭证

`fetch-confluence` 按以下顺序读取 PAT：

1. `CONFLUENCE_PAT` 环境变量，适用于 macOS、Linux 和 Windows 的 Bash 环境。
2. macOS 钥匙串服务 `alo7-confluence-pat`。

PAT、Cookie 和其他凭证不得写入仓库、日志或生成的文档。

脚本依赖 Bash、curl 和 jq。页面默认保存到系统临时目录，由操作系统负责清理。

## Redmine 凭证

Redmine MCP 从启动 Codex 的环境继承 `REDMINE_API_KEY`。`REDMINE_URL` 已由插件固定为
`https://redmine.saybot.net`。

API Key 不得写入仓库、日志或生成的文档。

## 维护

- MCP 与对应路由 Skill 作为一个插件版本发布。
- 凭证只保存在用户环境或系统凭证存储中。
- `legacy/` 只用于回溯，不加入插件。
