import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    let repo = Repository()

    @Published var today: Day = Day(date: "", state: .noPlan, lockedAt: nil, reckonedAt: nil, reckoningTime: "18:00", streakAfter: nil)
    @Published var todayTasks: [DailyTask] = []
    @Published var pendingReckoningDay: Day? = nil // Set if a previous day's reckoning is pending
    @Published var pendingReckoningTasks: [DailyTask] = []
    @Published var streak: Int = 0

    var onMenuBarLabelChanged: (() -> Void)?
    var onShowReckoning: (() -> Void)?
    var onShowPopover: (() -> Void)?

    private var reckoningTimer: Timer?
    private var midnightTimer: Timer?
    private var snoozeTimer: Timer?
    private var refreshTickTimer: Timer?

    // MARK: - Bootstrap

    func bootstrap() {
        // Auto-miss any previous-calendar-day rows (primary or suffixed) that were never
        // reckoned. Today and same-calendar-day suffixed sessions are protected by
        // Repository.autoMissDay's own guard.
        let today = Repository.todayString()
        let unreckoned = repo.unreckonedDays(before: today)
        for day in unreckoned {
            if Repository.calendarDatePrefix(day.date) < today {
                repo.autoMissDay(day.date)
            }
        }

        repo.setLastSeenDate(today)
        refreshState()
        scheduleAllTimers()
    }

    // MARK: - State refresh

    func refreshState() {
        let todayStr = Repository.todayString()

        // Day-rollover detection. Compare calendar-date prefixes so a same-day bonus
        // session change (e.g. lastSeen = '2026-06-05', todayStr = '2026-06-05') doesn't
        // accidentally trigger rollover handling.
        if let lastSeen = repo.lastSeenDate,
           Repository.calendarDatePrefix(lastSeen) != todayStr {
            // The primary row for the previous calendar day:
            if let prev = repo.getDay(Repository.calendarDatePrefix(lastSeen)),
               prev.state != .reckoned && prev.state != .autoMissed {
                if prev.state == .noPlan {
                    repo.autoMissDay(prev.date)
                } else {
                    repo.openReckoning(for: prev.date)
                }
            }
            // Any sibling bonus sessions that were left unreckoned auto-miss as well.
            for sibling in repo.siblingSessions(for: Repository.calendarDatePrefix(lastSeen)) {
                if sibling.state != .reckoned && sibling.state != .autoMissed {
                    repo.autoMissDay(sibling.date)
                }
            }
            repo.setLastSeenDate(todayStr)
            repo.setPlannerSnoozeCount(0)
            repo.setPlannerSnoozeUntil(nil)
        }

        // Pending reckoning takes precedence in the popover routing
        let pending = repo
            .unreckonedDays(before: todayStr)
            .first(where: { $0.state == .reckoningOpen || $0.state == .locked || $0.state == .allDone })
        if let pending = pending {
            self.pendingReckoningDay = pending
            self.pendingReckoningTasks = repo.tasks(for: pending.date)
        } else {
            self.pendingReckoningDay = nil
            self.pendingReckoningTasks = []
        }

        // Today
        self.today = repo.getOrCreateToday()
        self.todayTasks = repo.tasks(for: self.today.date)
        self.streak = repo.currentStreak

        onMenuBarLabelChanged?()
    }

    // MARK: - Menu bar progress

    /// Returns `(done, total)` for the menu bar progress icon, or `nil` when no
    /// progress should be shown (no plan yet, pending reckoning from yesterday,
    /// reckoning open, day already reckoned, or auto-missed).
    func menuBarProgress() -> (done: Int, total: Int)? {
        // A pending previous-day reckoning takes over the menu bar — don't show today's progress.
        if pendingReckoningDay != nil { return nil }

        switch today.state {
        case .locked, .allDone:
            let total = todayTasks.count
            guard total > 0 else { return nil }
            let done = todayTasks.filter { $0.status == .done }.count
            return (done, total)
        case .noPlan, .reckoningOpen, .reckoned, .autoMissed:
            return nil
        }
    }

    // MARK: - Menu bar text

    func menuBarText() -> String {
        let streakPart = "🔥 \(streak)"
        if pendingReckoningDay != nil {
            return "\(streakPart) · ⏰ Yesterday's reckoning"
        }
        switch today.state {
        case .noPlan:
            return "\(streakPart) · No plan yet — click to plan"
        case .locked:
            if let current = todayTasks.first(where: { $0.status == .pending }) {
                let truncated = String(current.title.prefix(40))
                return "\(streakPart) · \(truncated)"
            }
            return "\(streakPart) · …"
        case .allDone:
            return "\(streakPart) · ✅ All done — reckoning at \(today.reckoningTime)"
        case .reckoningOpen:
            return "\(streakPart) · ⏰ Reckoning open"
        case .reckoned:
            return "\(streakPart) · ✅ Day reckoned"
        case .autoMissed:
            return "\(streakPart) · 💀 Day missed"
        }
    }

    // MARK: - Planner

    func canSnoozePlanner() -> Bool {
        repo.plannerSnoozeCount < 1
    }

    /// User picks a delay; minutes is multiple of 30 between 30 and 120.
    func snoozePlanner(minutes: Int) {
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        repo.setPlannerSnoozeUntil(until)
        repo.setPlannerSnoozeCount(repo.plannerSnoozeCount + 1)
        scheduleSnoozeTimer()
    }

    func lockPlan(titles: [String]) {
        let _ = repo.lockToday(titles: titles)
        repo.setPlannerSnoozeUntil(nil)
        refreshState()
        // Schedule reckoning timers for today
        scheduleAllTimers()
    }

    /// Start a fresh bonus session for today's calendar date with a custom reckoning time.
    /// Streak isn't affected by this session — it's pure bonus.
    /// If the chosen reckoning time has already passed, open reckoning immediately
    /// rather than scheduling a timer that will never fire.
    func startNewSession(reckoningTime hhmm: String) {
        guard repo.startNewSession(reckoningTime: hhmm) != nil else {
            return
        }
        refreshState()

        if let target = parseReckoningTime(hhmm, on: Date()), target <= Date() {
            if today.state == .locked || today.state == .allDone {
                openReckoningNow()
                return
            }
        }
        scheduleAllTimers()
    }

    // MARK: - Done

    func markDone(taskId: Int64?) {
        guard let id = taskId else { return }
        repo.markDone(taskId: id)
        refreshState()
    }

    // MARK: - Reckoning

    func openReckoningNow() {
        repo.openReckoning(for: today.date)
        refreshState()
        onShowReckoning?()
    }

    func submitReckoning(date: String, retroactiveDoneIds: Set<Int64>, skipReasons: [Int64: String]) {
        let _ = repo.submitReckoning(date: date, retroactiveDoneIds: retroactiveDoneIds, skipReasons: skipReasons)
        refreshState()
    }

    func reckoningTimeForToday() -> Date? {
        return parseReckoningTime(today.reckoningTime, on: Date())
    }

    func setReckoningTime(_ hhmm: String) {
        repo.setReckoningTimeDefault(hhmm)
        // Update today's reckoning time iff today hasn't been reckoned yet.
        if today.state != .reckoned && today.state != .autoMissed {
            try? repo.db.write { dbConn in
                try dbConn.execute(
                    sql: "UPDATE days SET reckoning_time = ? WHERE date = ?",
                    arguments: [hhmm, self.today.date]
                )
            }
        }
        refreshState()
        scheduleAllTimers()
    }

    /// User-chosen delay: pick a new time before midnight for today's reckoning.
    /// If the chosen time has already passed (e.g., the user lingered in the picker
    /// long enough that the slot they picked is now in the past), open reckoning
    /// immediately rather than scheduling a timer that will never fire.
    func delayReckoning(to newTimeHHMM: String) {
        try? repo.db.write { dbConn in
            try dbConn.execute(
                sql: "UPDATE days SET reckoning_time = ? WHERE date = ?",
                arguments: [newTimeHHMM, self.today.date]
            )
        }
        refreshState()

        if let newTarget = parseReckoningTime(newTimeHHMM, on: Date()), newTarget <= Date() {
            // Past-time edge case: fire reckoning right now.
            if today.state == .locked || today.state == .allDone {
                openReckoningNow()
                return
            }
        }
        scheduleAllTimers()
    }

    // MARK: - History

    func history() -> [Day] {
        repo.historyLast(30)
    }

    func tasks(for date: String) -> [DailyTask] {
        repo.tasks(for: date)
    }

    // MARK: - Timers

    func scheduleAllTimers() {
        scheduleReckoningTrigger()
        scheduleMidnightAutoReckon()
        scheduleSnoozeTimer()
        scheduleRefreshTick()
        NotificationHandler.shared.scheduleReckoningWarnings(at: reckoningTimeForToday())
    }

    private func scheduleReckoningTrigger() {
        reckoningTimer?.invalidate()
        guard let target = reckoningTimeForToday(), target > Date() else { return }
        reckoningTimer = Timer.scheduledTimer(withTimeInterval: target.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.today.state == .locked || self.today.state == .allDone {
                    self.openReckoningNow()
                }
            }
        }
    }

    private func scheduleMidnightAutoReckon() {
        midnightTimer?.invalidate()
        let cal = Calendar.current
        guard let nextMidnight = cal.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else { return }
        let interval = max(5, nextMidnight.timeIntervalSinceNow)
        // Capture the date being closed out at schedule time. Reading self.today.date
        // when the timer fires is racy: refreshTickTimer (60s) can update self.today
        // past midnight first, causing us to auto-miss the new day instead of the old.
        let dateToClose = Repository.todayString()
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.repo.autoMissDay(dateToClose)
                self.refreshState()
                self.scheduleAllTimers()
            }
        }
    }

    private func scheduleSnoozeTimer() {
        snoozeTimer?.invalidate()
        guard let until = repo.plannerSnoozeUntil, until > Date() else { return }
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: until.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repo.setPlannerSnoozeUntil(nil)
                self?.refreshState()
                self?.onShowPopover?()
            }
        }
    }

    /// Refresh the menu bar label every minute so the reckoning time text stays accurate.
    private func scheduleRefreshTick() {
        refreshTickTimer?.invalidate()
        refreshTickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshState()
            }
        }
    }
}

// MARK: - Time helpers

func parseReckoningTime(_ hhmm: String, on day: Date) -> Date? {
    let parts = hhmm.split(separator: ":")
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
    var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
    comps.hour = h
    comps.minute = m
    comps.second = 0
    return Calendar.current.date(from: comps)
}

private let hhmmFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

func formatHHMM(_ date: Date) -> String {
    hhmmFormatter.string(from: date)
}
