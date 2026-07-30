---
name: fetch-redmine
description: Use when asked to retrieve, read, inspect, or summarize issues hosted on the self-hosted redmine.saybot.net instance.
---

# Fetch Redmine

Use `bash scripts/fetch-redmine.sh` to retrieve a Redmine issue as JSON.
Resolve the script path relative to this Skill directory, not the current working directory.

1. Extract the numeric issue ID from the supplied URL, or use the supplied issue ID directly.
2. Run `bash scripts/fetch-redmine.sh <issue-id> [output.json]`.
3. Omit `output.json` unless the user explicitly asks to keep the response. The script saves temporary output under `${TMPDIR:-/tmp}`.
4. Read the saved JSON to answer the user's request, including relevant journals, attachments, and relations.
5. Show the exact saved path to the user.
6. When the user explicitly requests a project or persistent path, pass that path.
7. Never print, log, copy, or include the API key in output.
8. If sandbox restrictions may have blocked Keychain or network access, retry with the required permission before reporting missing credentials.
9. Report authentication and permission failures without exposing credentials.
