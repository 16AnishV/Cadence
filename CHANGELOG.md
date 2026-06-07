# Changelog

## [1.4] — 2026-06-06

### Reckoning time picker

- **Native graphical DatePicker everywhere.** All three time pickers (Settings default, bonus session start, delay-reckoning popover) now use SwiftUI's `DatePicker(displayedComponents: .hourAndMinute)` instead of the custom dual hour/minute `Picker` rows. Renders as a tappable HH:MM field with hidden steppers — click to type, arrow keys to nudge. Smallest footprint, fully keyboard-driven, and the future-time variant drops ~50 lines of custom range-filtering logic in favor of the native `in: now...endOfDay` constraint.

### Settings

- **Inline "Default reckoning time" row.** Label, time picker, and `Apply` button now sit on a single row instead of stacking the header above the controls. Part of a broader minimalist/condensed direction for the app — prefer dense one-row layouts over multi-row sections when context already makes the meaning clear.

### Reckoning copy

- **Unified "Reckoning at HH:MM" phrasing.** The bonus session picker title, delay-reckoning picker title, and full-screen reckoning window caption all collapse onto the same short phrase. Replaces "Reckoning time for this session" / "Delay reckoning until…" / "Reckoning set for …".

### Project tooling

- **`pkill` / `killall` no longer denied.** `.claude/settings.json` previously blocked the entire `pkill:*` and `killall:*` patterns to keep the allowlist narrow, but this also blocked the standard `pkill -x Cadence` step in the build/relaunch loop, prompting on every iteration. Removed both deny rules; the explicit allow for `pkill -x Cadence` and `killall Finder Dock` is sufficient.

## [1.3] — 2026-06-06

### Reckoning time picker

- **Per-minute granularity actually delivered.** 1.2 announced this but the picker still snapped to quarter-hour increments. Now any of 60 minutes per hour is selectable and the default selection is now+30 unsnapped.

### Internal cleanup (no behavior change)

- **Shared `ReckoningTaskList` view.** `PendingReckoningView` and `ReckoningView` previously kept two near-identical copies of the same retroactive-done + skip-reason UI; they now share `Cadence/Views/ReckoningTaskList.swift` with a `.compact`/`.prominent` style toggle for popover vs. full-screen sizing.
- **Removed picker passthroughs.** `NewSessionPickerView` and `DelayReckoningView` were 3-line wrappers over `FutureTimePickerView`; call sites now use the picker directly.
- **Cached `DateFormatter` instances.** `Repository.todayString` (called every refresh tick) and the HH:MM / "plan locked at" formatters were rebuilding a `DateFormatter` per call; now hoisted to file-private `static let`.
- **Dead code purge.** Dropped the always-nil `icon: String?` element from `menuBarText`'s tuple return, an unused `_ = day` in `PendingReckoningView`, and the unused entries in `Day.Columns` / `DailyTask.Columns`. `Package.swift` no longer excludes the nonexistent `Resources/Assets.xcassets` path.

### Documentation

- **README project layout** now lists `MenuBarIconRenderer.swift`, `FutureTimePickerView.swift`, and `ReckoningTaskList.swift`.
- **README backlog** no longer hard-codes an absolute path to a per-machine design doc.
- **`.gitmessage`** now mentions `build_icon.sh` alongside `build_app.sh` for the `build` type, matching `COMMITS.md`.

## [1.2] — 2026-06-06

### App icon

- **First real app icon.** `Cadence/Resources/AppIcon.svg` (centered, scaled crop of the retro-sun logo) is now packaged as `Cadence.app/Contents/Resources/AppIcon.icns` and wired up via `CFBundleIconFile`. Shows in the About panel, notification banners, force-quit dialog, and Finder. (Cadence is `LSUIElement`, so no Dock presence.)
- **New `build_icon.sh` build step.** Renders SVG → 1024×1024 PNG via `qlmanage`, downscales to all 10 iconset dimensions via `sips`, packages with `iconutil -c icns`. Auto-invoked by `build_app.sh` when the `.icns` is missing.

### Reckoning time picker

- **Per-minute granularity.** All three time pickers (Settings default, bonus session start, delay-reckoning popover) now offer every minute 00–59 instead of only `:00 :15 :30 :45`.

### End-of-day popover copy

- **Terser ReckonedView and AutoMissedView.** Replaced the long descriptive sentences with `"New day, new chance. Plan tomorrow."` as the visual anchor, with a small `.link`-styled bonus-session button as a quiet escape hatch below. Removes the "OR" separator and prominent button that previously pulled the eye away from the primary message.

### Project tooling

- New `.claude/settings.json` with a permissions allowlist for the build/run/debug commands that need to bypass Claude Code's tool sandbox (`build_app.sh`, `pkill -x Cadence`, `open Cadence.app`, `build_icon.sh`, `qlmanage`, etc.) plus `deny` rules on broad `pkill:*` / `killall:*` patterns. Per-section comments in a `_comments` block document why each rule is needed.

## [1.1] — 2026-06-06

### Brand identity

- **New logo: half-sun with task-circle arc.** Filled amber half-disc with 5 cream-colored task circles sitting on the rim and 6 amber rays radiating from the upper half. Source files:
  - `cadence-logo-halfsun-v1.svg` — master mark with task circles
  - `cadence-logo-halfsun-v1-no-ticks.svg` — half-sun shape only
  - `cadence-logo-retrosun.svg` — retro-sunset variant: full disc with horizontal bands eroding the lower half

### Menu bar progress icon

- **Live progress visualization in the menu bar.** Replaced the textual `🔥 N · <task>` prefix with a half-sun progress icon when a plan is locked. Each task is a circle on the arc; circles fill amber from left to right as tasks are marked done.
- **Adapts to plan size.** Distinct icon variants for 1, 2, 3, 4, and 5-task plans — circles distributed evenly across the half-circle for each count.
- **Updates instantly.** No click required. The icon redraws the moment a task transitions to done.
- **Crisp at every menu bar height.** Rendered programmatically via `NSBezierPath` instead of pre-baked PNGs, so the icon stays sharp on every display density.
- **Larger circles.** Tick radius increased ~40% from initial sizing for better legibility at menu bar scale.
- **Hidden in non-progress states.** No icon during no-plan, reckoning-open, reckoned, or auto-missed states — text-only fallback. The icon disappears entirely when there's a pending previous-day reckoning so it doesn't misrepresent today's state.

### Reckoning time picker

- **Constrained to current time → midnight.** When picking a reckoning time for a bonus session or when delaying today's reckoning, hours before the current hour are no longer shown. Minute choices are filtered to only times after "now" when the selected hour equals the current hour.
- **Quarter-hour granularity** (00, 15, 30, 45) for fast picking.
- **Smart default.** Picker opens with the next quarter-hour ~30 minutes from now pre-selected, capped before midnight.
- **Past-time edge case handled.** If the user lingers in the picker long enough that their chosen time has already passed by the moment they confirm, reckoning fires immediately instead of scheduling a timer that would never trigger.
- **Settings unchanged.** The "Default reckoning time" in Settings remains unconstrained since it applies to future days.

### Reckoning window

- **New configured-at caption.** The full-screen reckoning window now shows when the plan was locked and what reckoning time was configured (e.g., *"Plan locked Jun 5, 2026 at 11:42 PM. Reckoning set for 18:00."*) — useful when you delay reckoning and want to see the original commit alongside the current setting.

### Project structure

- New `Cadence/MenuBarIconRenderer.swift` — programmatic icon rendering.
- New `Cadence/Views/FutureTimePickerView.swift` — shared time picker, replaces duplicated logic in `NewSessionPickerView` and `DelayReckoningView`.
- New `Cadence/Resources/MenubarIcons/` — 20 SVG design references (one per `(done, total)` state) kept as source-of-truth for the icon geometry. Excluded from the build; not shipped in the bundle.
- `AppCoordinator` gained `menuBarProgress() -> (done, total)?` for reading the icon state.
