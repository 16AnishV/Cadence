import Foundation
import GRDB

struct Repository {
    let db: DatabaseQueue

    init(db: DatabaseQueue = CadenceDatabase.shared) {
        self.db = db
    }

    // MARK: - Date helpers

    /// Hot-path formatter (called by every refresh tick + day-rollover check).
    /// `DateFormatter` is thread-safe for read after configuration; the cache
    /// stays valid because we always use the user's current calendar/timezone.
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        return f
    }()

    static func todayString(_ now: Date = Date()) -> String {
        dateOnlyFormatter.string(from: now)
    }

    /// Calendar date prefix from a session date string. '2026-06-05' -> '2026-06-05'.
    /// '2026-06-05-2' -> '2026-06-05'.
    static func calendarDatePrefix(_ sessionDate: String) -> String {
        // Plain calendar dates are exactly 10 chars. Suffixed sessions are longer.
        if sessionDate.count >= 10 {
            return String(sessionDate.prefix(10))
        }
        return sessionDate
    }

    /// True if this date string is a non-primary session (e.g. '2026-06-05-2').
    static func isSuffixedSession(_ sessionDate: String) -> Bool {
        return sessionDate.count > 10
    }

    /// The most recent session row for today's calendar date — either the plain
    /// '2026-06-05' row or the highest-suffixed sibling.
    func currentSessionDateString() -> String {
        let calendarToday = Self.todayString()
        let candidates = (try? db.read { d in
            try String.fetchAll(
                d,
                sql: "SELECT date FROM days WHERE date = ? OR date LIKE ? ORDER BY date DESC",
                arguments: [calendarToday, calendarToday + "-%"]
            )
        }) ?? []
        return candidates.first ?? calendarToday
    }

    /// Find the next available session suffix for the given calendar date.
    /// Returns '<calendar>-2' if only the primary exists, '<calendar>-3' if -2 exists, etc.
    func nextSessionDateString(for calendarDate: String) -> String {
        let existing = (try? db.read { d in
            try String.fetchAll(
                d,
                sql: "SELECT date FROM days WHERE date = ? OR date LIKE ?",
                arguments: [calendarDate, calendarDate + "-%"]
            )
        }) ?? []
        // Highest suffix used so far (1 if only the primary exists)
        var maxSuffix = 1
        for d in existing {
            if d == calendarDate { continue }
            if let dashIdx = d.lastIndex(of: "-"),
               let n = Int(d[d.index(after: dashIdx)...]) {
                if n > maxSuffix { maxSuffix = n }
            }
        }
        return "\(calendarDate)-\(maxSuffix + 1)"
    }

    // MARK: - App state

    func getState(_ key: String) -> String? {
        try? db.read { d in
            try String.fetchOne(d, sql: "SELECT value FROM app_state WHERE key = ?", arguments: [key])
        }
    }

    func setState(_ key: String, _ value: String) {
        try? db.write { d in
            try d.execute(sql: "INSERT INTO app_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", arguments: [key, value])
        }
    }

    var reckoningTimeDefault: String {
        getState("reckoning_time_default") ?? "18:00"
    }

    func setReckoningTimeDefault(_ value: String) {
        setState("reckoning_time_default", value)
    }

    var plannerSnoozeCount: Int {
        Int(getState("planner_snooze_count") ?? "0") ?? 0
    }

    func setPlannerSnoozeCount(_ value: Int) {
        setState("planner_snooze_count", String(value))
    }

    var plannerSnoozeUntil: Date? {
        guard let s = getState("planner_snooze_until"), let t = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    func setPlannerSnoozeUntil(_ date: Date?) {
        if let date = date {
            setState("planner_snooze_until", String(date.timeIntervalSince1970))
        } else {
            try? db.write { d in
                try d.execute(sql: "DELETE FROM app_state WHERE key = 'planner_snooze_until'")
            }
        }
    }

    var lastSeenDate: String? {
        getState("last_seen_date")
    }

    func setLastSeenDate(_ s: String) {
        setState("last_seen_date", s)
    }

    // MARK: - Days

    func getDay(_ date: String) -> Day? {
        try? db.read { d in
            try Day.fetchOne(d, key: date)
        }
    }

    /// Returns the active session row for today. If a suffixed session exists for
    /// today's calendar date, returns the highest-suffix one. Otherwise creates the
    /// plain calendar-date row in NO_PLAN state.
    func getOrCreateToday() -> Day {
        let sessionDate = currentSessionDateString()
        if let d = getDay(sessionDate) {
            return d
        }
        // No row exists yet — create the primary calendar-date row.
        let calendarToday = Self.todayString()
        let day = Day(
            date: calendarToday,
            state: .noPlan,
            lockedAt: nil,
            reckonedAt: nil,
            reckoningTime: reckoningTimeDefault
        )
        try? db.write { dbConn in
            try day.insert(dbConn)
            try dbConn.execute(sql: "UPDATE app_state SET value = '0' WHERE key = 'planner_snooze_count'")
            try dbConn.execute(sql: "DELETE FROM app_state WHERE key = 'planner_snooze_until'")
        }
        return day
    }

    /// Start a fresh session for today's calendar date with a custom reckoning time.
    /// Used after a previous session has been reckoned but the user wants to keep working.
    /// Returns the new Day row, or nil if the previous session for today isn't yet reckoned.
    @discardableResult
    func startNewSession(reckoningTime: String) -> Day? {
        let calendarToday = Self.todayString()
        let prevSession = currentSessionDateString()
        guard let prev = getDay(prevSession),
              prev.state == .reckoned || prev.state == .autoMissed else {
            return nil
        }
        let newDate = nextSessionDateString(for: calendarToday)
        let day = Day(
            date: newDate,
            state: .noPlan,
            lockedAt: nil,
            reckonedAt: nil,
            reckoningTime: reckoningTime
        )
        try? db.write { dbConn in
            try day.insert(dbConn)
            // Reset snooze for the new session.
            try dbConn.execute(sql: "UPDATE app_state SET value = '0' WHERE key = 'planner_snooze_count'")
            try dbConn.execute(sql: "DELETE FROM app_state WHERE key = 'planner_snooze_until'")
        }
        return day
    }

    func updateDayState(_ date: String, _ state: DayState) {
        try? db.write { dbConn in
            try dbConn.execute(sql: "UPDATE days SET state = ? WHERE date = ?", arguments: [state.rawValue, date])
        }
    }

    // MARK: - Tasks

    func tasks(for date: String) -> [DailyTask] {
        (try? db.read { d in
            try DailyTask
                .filter(DailyTask.Columns.date == date)
                .order(DailyTask.Columns.position)
                .fetchAll(d)
        }) ?? []
    }

    func currentTask(for date: String) -> DailyTask? {
        tasks(for: date).first { $0.status == .pending }
    }

    func progress(for date: String) -> (done: Int, total: Int) {
        let all = tasks(for: date)
        let done = all.filter { $0.status == .done }.count
        return (done, all.count)
    }

    // MARK: - Lock & Start

    @discardableResult
    func lockToday(titles: [String]) -> Day? {
        let cleanTitles = titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleanTitles.isEmpty, cleanTitles.count <= 5 else { return nil }
        let sessionDate = currentSessionDateString()
        let now = Date()

        return try? db.write { dbConn in
            // Ensure session row exists. If not, create the primary calendar-date row.
            if try Day.fetchOne(dbConn, key: sessionDate) == nil {
                let day = Day(date: sessionDate, state: .noPlan, lockedAt: nil, reckonedAt: nil, reckoningTime: reckoningTimeDefault)
                try day.insert(dbConn)
            }

            for (idx, title) in cleanTitles.enumerated() {
                var t = DailyTask(id: nil, date: sessionDate, position: idx, title: title, status: .pending, doneAt: nil, skipReason: nil)
                try t.insert(dbConn)
            }

            try dbConn.execute(
                sql: "UPDATE days SET state = ?, locked_at = ? WHERE date = ?",
                arguments: [DayState.locked.rawValue, now, sessionDate]
            )

            return try Day.fetchOne(dbConn, key: sessionDate)
        }
    }

    /// Append a single pending task to the current in-flight session. Unlike `lockToday`,
    /// there's intentionally no 5-task cap once a session has started — the planner limits
    /// the initial lock, but a running session can grow freely.
    @discardableResult
    func addTask(title: String) -> DailyTask? {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let sessionDate = currentSessionDateString()

        return try? db.write { dbConn in
            // Only allow adding to an in-flight session, never a reckoned/missed one.
            guard let day = try Day.fetchOne(dbConn, key: sessionDate),
                  day.state == .locked || day.state == .allDone else { return nil }

            let maxPos = try Int.fetchOne(
                dbConn,
                sql: "SELECT MAX(position) FROM tasks WHERE date = ?",
                arguments: [sessionDate]
            ) ?? -1

            var t = DailyTask(id: nil, date: sessionDate, position: maxPos + 1,
                              title: clean, status: .pending, doneAt: nil, skipReason: nil)
            try t.insert(dbConn)

            // A new pending task means the day is no longer "all done": flip ALL_DONE → LOCKED
            // so reckoning isn't prematurely available and TaskView shows the new task.
            if day.state == .allDone {
                try dbConn.execute(
                    sql: "UPDATE days SET state = ? WHERE date = ?",
                    arguments: [DayState.locked.rawValue, sessionDate]
                )
            }
            return t
        }
    }

    // MARK: - Reorder

    /// Persist a new task ordering for the given session. `orderedIds` must be the full set of
    /// task ids for that session, in the desired top-to-bottom order. Rewrites `position`
    /// contiguously (0..n). Only allowed while the session is in-flight (LOCKED/ALL_DONE),
    /// mirroring `addTask`'s guard so a reckoned/missed day can't be mutated.
    func reorderTasks(date: String, orderedIds: [Int64]) {
        try? db.write { dbConn in
            guard let day = try Day.fetchOne(dbConn, key: date),
                  day.state == .locked || day.state == .allDone else { return }
            // Guard against a stale ordering: only apply if orderedIds exactly matches the
            // session's current task-id set (protects against a task added/removed between
            // the UI snapshot and the drop).
            let currentIds = try Int64.fetchSet(
                dbConn, sql: "SELECT id FROM tasks WHERE date = ?", arguments: [date])
            guard Set(orderedIds) == currentIds else { return }
            for (idx, id) in orderedIds.enumerated() {
                try dbConn.execute(
                    sql: "UPDATE tasks SET position = ? WHERE id = ?", arguments: [idx, id])
            }
        }
    }

    // MARK: - Done

    func markDone(taskId: Int64) {
        try? db.write { dbConn in
            // Find which session this task belongs to so we update the right day row.
            let taskDate = try String.fetchOne(
                dbConn,
                sql: "SELECT date FROM tasks WHERE id = ?",
                arguments: [taskId]
            )
            try dbConn.execute(
                sql: "UPDATE tasks SET status = ?, done_at = ? WHERE id = ?",
                arguments: [TaskStatus.done.rawValue, Date(), taskId]
            )
            guard let sessionDate = taskDate else { return }

            let pendingCount = try Int.fetchOne(
                dbConn,
                sql: "SELECT COUNT(*) FROM tasks WHERE date = ? AND status = ?",
                arguments: [sessionDate, TaskStatus.pending.rawValue]
            ) ?? 0
            if pendingCount == 0 {
                try dbConn.execute(
                    sql: "UPDATE days SET state = ? WHERE date = ? AND state = ?",
                    arguments: [DayState.allDone.rawValue, sessionDate, DayState.locked.rawValue]
                )
            }
        }
    }

    // MARK: - Reckoning

    func openReckoning(for date: String) {
        try? db.write { dbConn in
            try dbConn.execute(
                sql: "UPDATE days SET state = ? WHERE date = ? AND state IN (?, ?)",
                arguments: [
                    DayState.reckoningOpen.rawValue,
                    date,
                    DayState.locked.rawValue,
                    DayState.allDone.rawValue
                ]
            )
        }
    }

    /// Submit reckoning. retroactiveDoneIds will be marked DONE; for any remaining PENDING tasks,
    /// skipReasons[taskId] is required (caller validates non-empty before calling).
    func submitReckoning(date: String, retroactiveDoneIds: Set<Int64>, skipReasons: [Int64: String]) {
        try? db.write { dbConn in
            let now = Date()

            for tid in retroactiveDoneIds {
                try dbConn.execute(
                    sql: "UPDATE tasks SET status = ?, done_at = ? WHERE id = ?",
                    arguments: [TaskStatus.done.rawValue, now, tid]
                )
            }

            for (tid, reason) in skipReasons {
                try dbConn.execute(
                    sql: "UPDATE tasks SET status = ?, skip_reason = ? WHERE id = ?",
                    arguments: [TaskStatus.skipped.rawValue, reason, tid]
                )
            }

            try dbConn.execute(
                sql: "UPDATE days SET state = ?, reckoned_at = ? WHERE date = ?",
                arguments: [DayState.reckoned.rawValue, now, date]
            )
        }
    }

    /// Auto-miss a day at midnight: any pending tasks become skipped (no reason).
    /// Refuses to auto-miss today (ever) or days already in a terminal state.
    func autoMissDay(_ date: String) {
        // Compare calendar-date prefixes so a suffixed same-day session is correctly
        // considered "today" until the calendar rolls over.
        if Self.calendarDatePrefix(date) >= Self.todayString() {
            return
        }
        try? db.write { dbConn in
            let currentState = try String.fetchOne(
                dbConn,
                sql: "SELECT state FROM days WHERE date = ?",
                arguments: [date]
            )
            guard let s = currentState,
                  s != DayState.reckoned.rawValue,
                  s != DayState.autoMissed.rawValue else {
                return
            }
            try dbConn.execute(
                sql: "UPDATE tasks SET status = ? WHERE date = ? AND status = ?",
                arguments: [TaskStatus.skipped.rawValue, date, TaskStatus.pending.rawValue]
            )
            try dbConn.execute(
                sql: "UPDATE days SET state = ? WHERE date = ?",
                arguments: [DayState.autoMissed.rawValue, date]
            )
        }
    }

    // MARK: - History

    /// Last n primary calendar-date rows. Suffixed (bonus) sessions are filtered out
    /// so the history view shows one row per calendar day.
    func historyLast(_ n: Int) -> [Day] {
        (try? db.read { d in
            // Plain calendar dates are exactly 10 chars; suffixed are longer.
            try Day
                .filter(sql: "length(date) = 10")
                .order(Day.Columns.date.desc)
                .limit(n)
                .fetchAll(d)
        }) ?? []
    }

    /// Sibling sessions that share a calendar date (used by history detail to optionally
    /// show bonus sessions for transparency).
    func siblingSessions(for calendarDate: String) -> [Day] {
        (try? db.read { d in
            try Day
                .filter(Column("date").like(calendarDate + "-%"))
                .order(Day.Columns.date)
                .fetchAll(d)
        }) ?? []
    }

    /// All days that exist but aren't reckoned/auto-missed yet (typically yesterday if app wasn't run)
    func unreckonedDays(before today: String) -> [Day] {
        (try? db.read { d in
            try Day
                .filter(Day.Columns.date < today)
                .filter(Day.Columns.state != DayState.reckoned.rawValue)
                .filter(Day.Columns.state != DayState.autoMissed.rawValue)
                .order(Day.Columns.date)
                .fetchAll(d)
        }) ?? []
    }
}
