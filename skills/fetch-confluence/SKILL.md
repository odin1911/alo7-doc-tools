---
name: fetch-confluence
description: Use when asked to retrieve, read, inspect, or summarize documentation hosted on the self-hosted confluence.alo7.cn instance.
---

# Fetch Confluence

Use `bash scripts/fetch-confluence.sh` to retrieve rendered page HTML.
Resolve the script path relative to this Skill directory, not the current working directory.

1. Extract the numeric `pageId` from the supplied URL, or use the supplied page ID directly.
2. Run `bash scripts/fetch-confluence.sh <pageId> [output.html]`.
3. Omit `output.html` unless the user explicitly asks to keep the document. The script saves temporary output under `${TMPDIR:-/tmp}`.
4. Show the exact saved path to the user.
5. When the user explicitly requests a project or persistent path, pass that path.
6. Never print, log, copy, or include the PAT in output.
7. If sandbox restrictions may have blocked Keychain or network access, retry with the required permission before reporting missing credentials.
8. Report authentication and permission failures without exposing credentials.
