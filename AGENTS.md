# Agent instructions

## Project Guidance

- Use [README.md](README.md) for project usage and [CONTRIBUTING.md](CONTRIBUTING.md)
  for development workflows. Read the relevant sections before they are needed.
  Reuse guidance already read unless the documents change or the task needs additional sections.
- Follow the task and agreed review checkpoints. Report findings outside the task separately.
- Work autonomously within the authorized scope.
  Do not ask again for routine reads, checks, or scoped reversible edits.

## Development Practice

- Keep changes focused, reuse existing implementations, and prefer small modules
  with a clear purpose. Avoid unrelated refactors, dependency upgrades, and formatting changes.
- For behavior changes, write a focused test first and confirm that it fails
  for the expected reason.
  Make the smallest change that passes, then refactor if needed.

## Verification and handoff

- Run the applicable checks in [CONTRIBUTING.md](CONTRIBUTING.md).
  Summarize what changed, which checks ran, and their results.
  Explain failures, skips, and anything left unverified.
- Distinguish local checks from GitHub CI runs, and report platform coverage accurately.

## Worktree Safety

- Do not commit directly on `main`.
- Inspect the working tree before editing and preserve existing user changes.
  Do not overwrite, clean, stage, commit, rewrite, or revert unrelated changes
  without explicit authorization.
- Commit, push, merge, or create, edit, or delete GitHub content
  only with explicit user authorization.
  Approval of a design or code review does not authorize these actions.
  Existing authorization remains valid within its scope.
- When authorized to create a GitHub issue or pull request,
  assign it to the authenticated GitHub user.
- Apply dotfiles or run installers against the user's real environment
  only with explicit authorization.
  Do not source the user's shell startup files for investigation or validation.
