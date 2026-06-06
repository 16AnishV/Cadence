# Commit conventions

Cadence uses [Conventional Commits](https://www.conventionalcommits.org/). The future
`cadence-changelog` skill parses `git log` output to generate `CHANGELOG.md`, so the
format matters.

## Format

```
<type>(<optional scope>): <imperative subject, ≤72 chars>

<wrap body at ~72 cols. Explain *why*, not *what*. Multiple paragraphs OK.>

<optional footer: BREAKING CHANGE: ..., Co-authored-by: ..., refs #N>
```

- **Subject** uses the imperative mood ("add", "fix", "rewrite") — not "added"/"adds".
- **Body** is optional for trivial commits but expected for anything user-visible. Explain motivation, tradeoffs, side effects.
- **Footer** is rarely needed; reserve for breaking changes and external references.

## Allowed types

| Type | Meaning | Changelog section |
|------|---------|-------------------|
| `feat` | User-visible new capability | Features |
| `fix` | Bug fix | Fixes |
| `ux` | UI / copy / visual polish, no new capability | UX |
| `build` | `build_app.sh`, `build_icon.sh`, `Package.swift`, `.icns`, `Info.plist` | Build |
| `refactor` | Code restructure, no behavior change | omitted by default |
| `chore` | Tooling, scripts, config, repo housekeeping | omitted by default |
| `docs` | README / CHANGELOG / COMMITS edits | omitted by default |
| `style` | Formatting only, no semantic change | omitted by default |

## Scopes (optional)

Free-form, lowercase. Examples used so far:

- `ui` — anything in `Cadence/Views/`
- `storage` — `Repository.swift`, `Database.swift`, schema changes
- `notifications` — `NotificationHandler.swift` and reckoning timers
- `icon` — menu bar icon or app icon
- `picker` — time pickers
- `streak` — streak math
- `session` — multi-session-per-day logic
- `claude` — `.claude/` config

## Examples

```
ux(picker): allow per-minute reckoning time selection

Settings, bonus session, and delay-reckoning pickers all moved from
quarter-hour increments to every minute 00–59. The 15-min granularity
felt artificially restrictive once the user wanted to reckon at, e.g.,
17:42.
```

```
feat(session): support multi-session-per-day with suffixed dates

After a day is reckoned, the user can now start a fresh "bonus" session
within the same calendar date. Implementation uses suffixed date keys
(2026-06-05-2, -3, ...) so existing primary-day rows stay untouched and
streak math is unchanged. Bonus sessions don't count toward streak.
```

```
build(icon): generate AppIcon.icns from AppIcon.svg

New build_icon.sh: rasterizes via qlmanage, downscales with sips, packs
with iconutil. Auto-invoked by build_app.sh when AppIcon.icns is missing.
```

## What NOT to do

- Don't squash unrelated changes into one commit. One logical change = one commit.
- Don't reword history with `--amend` or `rebase -i` once it's pushed (and once
  there's a remote).
- Don't skip the body for non-trivial commits. The changelog skill needs context.
- Don't use `feat` for refactors. The reader will be confused when nothing visibly
  changes.
