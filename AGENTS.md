# Agent instructions

## Context

- Read [README.md](README.md) for repository usage and [CONTRIBUTING.md](CONTRIBUTING.md) for development and maintenance at the start of each new conversation.
- Reuse that context throughout the conversation; do not reread these documents before every change.

## Scope and workspace

- Follow the current task and agreed review checkpoints. Report findings outside the task separately.
- Inspect the working tree before editing. Preserve existing user changes; do not overwrite, revert, or clean them without authorization.
- Work autonomously within the authorized scope. Do not request repeated confirmation for routine reads, checks, or scoped reversible edits.

## Local environment

- Apply dotfiles or run dotfile installers against the user's real environment only with explicit authorization.
- Do not source the user's actual shell startup files for investigation or validation.

## Git and GitHub actions

- Commit, push, merge, or create, edit, or delete GitHub content only with explicit user authorization.
- Approval of a design or code review does not automatically authorize commits or remote changes.
- Existing authorization remains valid within its scope; do not request it again unless the scope changes.

## Verification and handoff

- Summarize what changed, which checks actually ran, their results, and anything left unverified.
- Distinguish local checks from GitHub CI runs, and report platform coverage accurately.
