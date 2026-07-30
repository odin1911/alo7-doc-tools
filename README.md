# ALO7 Doc Tools

ALO7 内部文档工具的 Codex Skills 仓库。

## Skills

| Skill | 用途 | 状态 |
| --- | --- | --- |
| `fetch-confluence` | 获取自建 Confluence 页面 | 可用 |
| `fetch-redmine` | 获取自建 Redmine issue | 可用 |

每个 Skill 都在 `skills/<skill-name>/` 中自包含并独立安装。仓库中的
`skills/` 是唯一源码；`~/.codex/skills/` 中的内容只是 Codex 安装副本，
不使用符号链接。

## 安装与更新

可以直接要求 Codex：

```text
请从 GitHub 仓库 odin1911/alo7-doc-tools 的 skills/fetch-confluence 路径安装 Skill。
```

Skill 更新并推送到 GitHub 后，要求 Codex 从相同仓库路径重新安装或更新，
然后重启 Codex。

## Confluence 凭证

`fetch-confluence` 按以下顺序读取 PAT：

1. `CONFLUENCE_PAT` 环境变量，适用于 macOS、Linux 和 Windows 的 Bash 环境。
2. macOS 钥匙串服务 `alo7-confluence-pat`。

PAT、Cookie 和其他凭证不得写入仓库、日志或生成的文档。

脚本依赖 Bash、curl 和 jq。页面默认保存到系统临时目录，由操作系统负责清理。

## Redmine 凭证

`fetch-redmine` 按以下顺序读取 API Key：

1. `REDMINE_API_KEY` 环境变量，适用于 macOS、Linux 和 Windows 的 Bash 环境。
2. macOS 钥匙串服务 `alo7-redmine-api-key`。

可通过 `REDMINE_BASE_URL` 覆盖默认实例 `https://redmine.saybot.net`。API Key
不得写入仓库、日志或生成的文档。

脚本依赖 Bash、curl 和 jq。issue 默认保存到系统临时目录，由操作系统负责清理。

## 维护

- 一个文档系统对应一个独立 Skill。
- 只有需要统一安装、MCP、Hook 或其他扩展能力时才升级为 Codex Plugin。
