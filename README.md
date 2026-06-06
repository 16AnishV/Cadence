# Cadence

A macOS menu bar accountability coach.

Plan 1–5 tasks in the morning, lock the list, work through them one at a time. At reckoning time, a full-screen window blocks your screen and asks why you skipped what you skipped. Build a streak; lose it when you skip.

## What it does

- **Morning planner** — type 1–5 tasks in priority order, click **Lock & Start**. List is immutable until tomorrow.
- **Single-task UI** — menu bar shows `🔥 N · <current task>`. One **Done** button. No skip button.
- **Pre-reckoning warnings** — notifications at T-20 and T-10 minutes before reckoning. Each offers a "Delay" action so you can push reckoning back if you're deep in something.
- **Full-screen reckoning** — at reckoning time, a blocking window appears. For each unfinished task, type why you didn't do it. You can also retroactively mark tasks as Done if you forgot to click the button. Submit to end the day.
- **Streak** — all tasks Done at reckoning → streak +1. Anything skipped → streak resets to 0.
- **Missed days auto-reset** — if you don't submit reckoning by midnight, the day auto-misses, streak resets to 0.

## Build & run

```sh
# Build the .app
./build_app.sh

# Launch
open Cadence.app
```

The bundle is ad-hoc codesigned. To run on your machine, that's enough. For distribution you'd need a Developer ID + notarization (out of scope for v1).

## Database location

```
~/Library/Application Support/Cadence/cadence.sqlite
```

Single SQLite file. Backups: just copy the file. Reset: delete the file (you lose all history).

## Project layout

```
Cadence/
├── Package.swift                      Swift Package manifest
├── build_app.sh                       Builds .app bundle from swift build output
└── Cadence/
    ├── main.swift                     Entry point (NSApplication + AppDelegate)
    ├── AppDelegate.swift              NSStatusItem, popover, window controllers
    ├── AppCoordinator.swift           Timers, day rollover, state transitions
    ├── NotificationHandler.swift      UNUserNotificationCenter scheduling
    ├── Models/
    │   ├── Day.swift                  Day record + GRDB conformance
    │   ├── Task.swift                 DailyTask record + GRDB conformance
    │   └── DayState.swift             Enums (DayState, TaskStatus)
    ├── Storage/
    │   ├── Database.swift             GRDB DatabaseQueue + migrations
    │   └── Repository.swift           CRUD: today, lock, done, reckon, history
    └── Views/
        ├── PopoverRoot.swift          Routes by day state
        ├── PlannerView.swift          Morning planner (1–5 task fields)
        ├── TaskView.swift             Current-task surface (Done button)
        ├── PendingReckoningView.swift Re-entry block for missed reckoning
        ├── ReckoningWindow.swift      Full-screen blocking reckoning
        ├── HistoryView.swift          Last 30 days drilldown
        └── SettingsView.swift         Reckoning time, launch-at-login
```

## Day state machine

```
NO_PLAN ──Lock──▶ LOCKED ──Done×N──▶ ALL_DONE ──reckoning_time──▶ RECKONING_OPEN ──Submit──▶ RECKONED
                    │                                                                   │
                    └─────────────────reckoning_time────────────────────────────────────┘

Any unreckoned state at midnight ──▶ AUTO_MISSED (streak = 0)
```

## Permissions to grant on first launch

- **Notifications** — required for pre-reckoning warnings. Cadence requests this on first launch.
- **Launch at login** — toggle in Settings. Required for reliable reckoning, since Cadence has no background daemon.

## Backlog (post-v1)

Everything that isn't shipped yet. See the design doc at
`/Users/anishvelagapudi/.claude/plans/build-a-mac-iphone-app-steady-flame.md`
for the prioritized roadmap (v2: iPhone companion. v3: accountability sharpening. etc.).
