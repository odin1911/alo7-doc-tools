---
name: fetch-redmine
description: Use when asked to retrieve, read, inspect, or summarize issues hosted on the self-hosted redmine.saybot.net instance.
---

# Fetch Redmine

Use `bash scripts/fetch-redmine.sh` to retrieve a Redmine issue as JSON.
Resolve the script path relative to this Skill directory, not the current working directory.

## Refresh and cleanup policy

- For a new task, fetch and analyze the document once before using it as evidence.
- By default, reuse information already extracted in the current task; do not fetch again or repeat the analysis.
- Reread the same saved output only when context compression or an exact check makes it necessary; this is not a refresh.
- Fetch again only when the user explicitly asks to refresh. State that the evidence was refreshed and replace the earlier basis with the new result.
- Do not compare the full old and new content unless the user asks.
- Delete default temporary output after its final read; keep output paths explicitly requested by the user.

## Procedure

1. Extract the numeric issue ID from the supplied URL, or use the supplied issue ID directly.
2. Run `bash scripts/fetch-redmine.sh <issue-id> [output.json]`.
3. Omit `output.json` unless the user explicitly asks to keep the response. The script saves temporary output under `${TMPDIR:-/tmp}`.
4. Read the saved JSON to answer the user's request, including relevant journals, attachments, and relations.
5. Show the exact saved path to the user.
6. When the user explicitly requests a project or persistent path, pass that path.
7. Never print, log, copy, or include the API key in output.
8. If sandbox restrictions may have blocked Keychain or network access, retry with the required permission before reporting missing credentials.
9. Report authentication and permission failures without exposing credentials.
