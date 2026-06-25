# AGENTS.md

## Code Comments

- Add comments when they clarify intent, domain rules, edge cases, lifecycle or concurrency constraints, temporary implementation boundaries, or non-obvious calculations.
- Prefer precise comments that explain why the code exists or what invariant it protects.
- Do not comment obvious mechanics. Rename, extract, or simplify the code instead.
- Keep comments current when behavior changes. Remove stale comments in the same change.
- For temporary placeholders, name the ticket or workstream expected to replace them.

## Story Completion Evidence

- Do not consider a Jira story Done until evidence is attached to the story or linked PR.
- Evidence must include at least one of: a demo recording, screenshots, passing test output, console output, or clear manual verification steps.
- UI-facing stories should include a screenshot or demo unless there is a specific reason they cannot.
- Domain, backend, release, and documentation stories may use focused test results, command output, health checks, or reproducible verification steps instead of screenshots.
- When moving a story to Done, add a brief Jira comment with the PR link and the evidence location or verification summary.
