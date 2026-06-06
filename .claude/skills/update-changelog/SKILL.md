---
name: update-changelog
description: Append a new versioned section to Cadence's CHANGELOG.md by reading commits since the last release, plus the live conversation context for nuance and motivation. Use when the user says "update the changelog", "/update-changelog", "ship a new release", "bump the version", "what's new", or asks to summarize recent Cadence work into the changelog. Also use proactively when significant work has shipped this session and the user is wrapping up.
---

# Update Cadence Changelog

Cadence's `CHANGELOG.md` is the user-facing record of what's shipped. It's organized by version (`[1.2]`, `[1.3]`, ...) with each entry grouped into thematic subsections like *App icon*, *Reckoning time picker*, *Project tooling*. Each version increments by `0.1` regardless of how big or small the changes are — there's no semver judgment.

This skill produces the next entry by combining two sources:

1. **Git log since the last release** — the `Conventional Commits` history from `<last-version-tag>..HEAD`. This tells us *what* changed and *which files*.
2. **The current conversation context** — what the user said, why they made the choices they did, what they considered and rejected. This tells us *why* it changed and *how to talk about it*.

Without (2), the changelog reads like a robotic commit dump. Without (1), the changelog drifts from reality. Both are needed.

## When to use

- The user asks for it directly: "update the changelog", "/update-changelog", "ship a release", "bump version", "what's new".
- Wrapping up a session that landed multiple non-trivial commits and the user hasn't run the skill yet — proactively suggest it.

## Pre-flight checks

Before doing anything else:

1. **Confirm we're inside the Cadence repo.** Run `git -C /Users/anishvelagapudi/Documents/VibeCode/Cadence status` to verify. If the working tree has uncommitted changes, **stop and ask the user whether to commit them first** — uncommitted changes won't make it into the changelog and that's almost always a mistake.
2. **Read the current `CHANGELOG.md`** in full so you understand its style, structure, and the last version number. Match the existing voice exactly.
3. **Read `COMMITS.md`** to refresh on which commit types map to which changelog sections.

## Determine the version range

Find the boundary between "already in the changelog" and "not yet in the changelog":

1. Parse the latest version header from `CHANGELOG.md`. Format: `## [X.Y] — YYYY-MM-DD`. The first such header from the top is the latest version.
2. Check if a matching git tag exists: `git -C <repo> tag -l "v<X.Y>"`. The convention is tags are prefixed `v` (e.g. `v1.2`).
   - **If the tag exists**: range is `v<X.Y>..HEAD`.
   - **If no tag exists** (likely the first time this skill runs): range is "everything in the repo" — use `git log --reverse --pretty=...`. The very first import commit (`chore: import Cadence v1.2 working tree`) is the boundary; anything *after* it is fair game.
3. Compute the new version: `X.(Y+1)`. So if the latest is `1.2`, the new entry is `1.3`. If `1.9`, then `1.10` (no rollover to `2.0`).

Confirm the range with the user before continuing if there's any ambiguity ("I see commits since v1.2 — should I draft v1.3 covering those?").

## Gather commits

Use this exact format for fetching commits, since the skill needs the full body to extract the *why*:

```
git -C /Users/anishvelagapudi/Documents/VibeCode/Cadence log <range> \
  --pretty=format:"---COMMIT---%n%H%n%s%n%n%b" --no-merges
```

Output is a stream of `---COMMIT---` separated blocks: `<sha>`, blank, `<subject>`, blank, `<body>`. Parse this; do not rely on `git log` defaults.

Filter out commits whose Conventional Commits type is in this set: `refactor`, `chore`, `style`, `docs`. Those don't appear in the public changelog by default. Exception: a `chore` commit MAY appear if it represents user-visible tooling like a new build script or repo restructure that affects how the user works — use judgment. When in doubt, omit and ask.

## Group commits by section

Map types to changelog section headings. Existing pattern from prior entries:

| Type | Section heading |
|------|-----------------|
| `feat` | "Features" or a topic-named section like "App icon" if multiple feats are themed |
| `fix` | "Fixes" |
| `ux` | "UX" or a topic-named section like "End-of-day popover copy" |
| `build` | "Build" |
| `chore` (only if user-visible) | "Project tooling" or topic-named |

Look at how the existing `[1.1]` and `[1.2]` entries group things — they prefer **topic-themed section names** ("Brand identity", "Menu bar progress icon", "Reckoning time picker") over generic "Features" / "Fixes". Match that style. If two `feat` commits both touch the menu bar icon, group them under one "Menu bar icon" subsection rather than two bullets in "Features".

Within each section, use bold lead-ins followed by prose:

```
- **Per-minute granularity.** All three time pickers (Settings default, ...) now offer every minute 00–59 instead of only `:00 :15 :30 :45`.
```

Lead-in is one short noun phrase; the rest of the bullet is plain prose. **Don't** lead with the verb ("Added", "Fixed") — match the existing entries' noun-phrase style.

## Pull motivation from conversation context

This is the step that makes the changelog actually good. For each commit, ask: *what did the user want, what tradeoffs did we discuss, what made this choice the right one?* That context lives in the current conversation, not in the commit body.

Examples of conversation context worth surfacing:
- "User found the previous design pulled too much attention to the bonus-session button" → goes into the UX entry.
- "User specified 'i don't want to allow all pkills, only ones that try to kill cadence specifically'" → explains why the deny rules exist, not just *that* they exist.
- "User considered semver auto-bumping but chose .1-increments for simplicity" → context for a versioning section if relevant.

If the conversation has no context for a commit (e.g. it was committed in a prior session), fall back to the commit body alone. Don't make up motivation.

## Write the entry

Insert above the most recent version, not at the end. The newest version goes first.

Template:

```markdown
## [<NEW_VERSION>] — <YYYY-MM-DD>

### <Topic-themed section 1>

- **<Short noun lead-in>.** <prose body, 1–3 sentences. Why, not just what. Wrap at ~100 cols.>
- **<...>.** <...>

### <Topic-themed section 2>

- **<...>.** <...>
```

Use today's date in `YYYY-MM-DD` format. Run `date +%Y-%m-%d` to get it; don't guess.

## Tag the release

After writing the entry, propose creating the corresponding annotated git tag:

```
git -C /Users/anishvelagapudi/Documents/VibeCode/Cadence tag -a v<NEW_VERSION> -m "v<NEW_VERSION>"
```

Tags are how subsequent runs of this skill find the boundary. Without the tag, the next run can't tell what's "new". **Don't** push the tag automatically — let the user decide when to `git push --tags` (or paired with the next regular push).

## Commit the changelog itself

The CHANGELOG.md edit needs to be its own commit, with a `docs` type so it doesn't pollute the *next* changelog round:

```
docs: changelog v<NEW_VERSION>

<one-line summary of what's in the entry>
```

The skill should propose this commit but let the user approve. Use the standard interactive `git commit` flow rather than `-m` so the user can adjust the message if they want.

## Verification

After running the skill, the user should be able to confirm:

1. `head -40 CHANGELOG.md` shows the new entry above the previous latest, with today's date.
2. `git log --oneline -5` shows the new `docs: changelog vX.Y` commit.
3. `git tag -l` shows the new `vX.Y` tag.
4. The entry's bullet count roughly matches the visible commits in the range, *minus* anything filtered (refactor/chore/style/docs).
5. Each bullet's lead-in is a short noun phrase; the prose explains *why*, not just *what*.

## Edge cases

- **No new commits in range.** Tell the user, don't write an empty entry. ("Nothing has been committed since v1.2 — there's nothing to add to the changelog yet.")
- **Range spans hundreds of commits.** Suggest splitting into multiple version bumps, or ask the user if they want one big consolidated entry.
- **Commit doesn't follow Conventional Commits.** Flag it to the user; ask whether to include it (and under which section) or skip. Don't silently invent a type.
- **Working tree dirty.** Refuse to proceed until the user either commits or explicitly says "skip those, just changelog what's committed."
- **The current conversation has no context relevant to the commits** (e.g. fresh session, asking to update the changelog from history alone). Skip the motivation-enrichment step and rely on commit bodies. Note this to the user — they may want to run it during the actual implementation session next time for richer prose.
