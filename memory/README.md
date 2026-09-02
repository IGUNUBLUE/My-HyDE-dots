# Repository memory

This directory stores durable operational knowledge for maintainers and coding agents. It complements `AGENTS.md`: instructions define how work must be performed, while memories explain why a current safeguard or decision exists.

## Reading workflow

1. Read [`index.md`](index.md) before changing desktop behavior.
2. Open every active memory whose scope or tags match the component being changed.
3. Verify drift-prone facts against the live machine and current upstream sources.
4. Treat a memory as context, not as permission to make unrelated changes.

## Writing workflow

- Create one file per decision or incident from [`template.md`](template.md).
- Use a stable `YYYY-MM-DD-short-slug.md` filename.
- Record only concise evidence needed to reproduce or review the decision.
- Add the file to `index.md` and mark it `active`, `monitoring`, `resolved`, or `superseded`.
- When resolving an entry, preserve it and record the validation that allowed the safeguard to be removed.

Never store passwords, tokens, private keys, usernames, home-directory paths, device serial numbers, raw logs, histories, or transient generated state here.
