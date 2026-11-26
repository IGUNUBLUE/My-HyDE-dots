# Issue tracker: Local Markdown

Specs and issues live in `.scratch/<feature-slug>/` in this repository.

- Specification: `spec.md`.
- Tickets: one file per ticket in `issues/<NN>-<slug>.md`, numbered from `01`.
- State: a `Status:` line using the roles in `triage-labels.md`.
- Dependencies: `Blocked by:` names ticket files; work blockers first.
- Conversation: append under `## Comments` when needed.

When a skill asks to publish or fetch an issue, write or read its local file.
External issue and pull request publication requires an explicit request.
