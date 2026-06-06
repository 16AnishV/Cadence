# Cadence — project context for Claude

## What this project is

Cadence is a Mac menu bar accountability coach. Native SwiftUI + AppKit (`NSStatusItem` +
`NSPopover` + a borderless `NSWindow` for the reckoning surface). SwiftPM executable target,
no Xcode project. Local-only — no remote APIs, no analytics, no auth. SQLite via GRDB.

The full design doc lives in this repo's history; see `CHANGELOG.md` for the shipping log.

## Commit conventions

This repo uses Conventional Commits. See `COMMITS.md` for the full reference. Quick summary:

```
<type>(<optional scope>): <imperative subject ≤72 chars>

<wrap body at ~72 cols. Explain *why*, not *what*.>
```

Allowed types: `feat`, `fix`, `ux`, `build`, `refactor`, `chore`, `docs`, `style`. Always
sign commits — the personal GPG key is auto-selected via `~/.gitconfig`'s `includeIf` block.

When making commits as part of a task, follow the convention exactly. Use `ux` for UI/copy
changes that don't add or fix capability. Use `build` for `build_app.sh`, `build_icon.sh`,
`Package.swift`, icon assets, `Info.plist`. Don't use `feat` for refactors.

## Build and run

The full rebuild-and-run loop is:

```
./build_app.sh                 # SwiftPM build + .app bundle
pkill -x Cadence               # kill the running instance
open Cadence.app               # relaunch
```

These three commands are pre-allowlisted in `.claude/settings.json` along with their
`dangerouslyDisableSandbox` requirements documented inline. When iterating on UI, run all
three after each meaningful change.

`build_icon.sh` regenerates `AppIcon.icns` from `Cadence/Resources/AppIcon.svg`. Auto-invoked
by `build_app.sh` when `.icns` is missing — usually only matters when the logo changes.

## Changelog discipline

`CHANGELOG.md` is the user-facing release log. It's NOT updated commit-by-commit — instead,
the `update-changelog` skill (in `.claude/skills/`) batches commits into a versioned entry.
Versions increment by `0.1` always (never semver judgment).

**Proactively suggest running `update-changelog`** when:
- The session has produced 3+ user-visible commits without a changelog update, OR
- The user appears to be wrapping up the session ("looks good", "I think we're done", `/exit`-ish), OR
- The user asks "what changed?" / "what's new?"

Don't run it without confirming — the user may want to land more changes first.

## What NOT to do

- Don't edit historical CHANGELOG.md entries. Each version captures what was true at ship time.
- Don't modify the work git identity (`anishvelagapudi@salesforce.com`) — `~/.gitconfig`
  already routes Cadence to the personal identity via `includeIf`. Verify with
  `git config user.email` if confused.
- Don't push to `origin` without confirming. The remote is `git@github.com:16AnishV/Cadence.git`
  on the personal account; auto-push could surprise the user.
- Don't add documentation, README, or markdown files unprompted. The repo deliberately stays
  lean — `CHANGELOG.md`, `COMMITS.md`, `CLAUDE.md`, `README.md` are the only doc files.
