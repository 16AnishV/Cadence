import Foundation

enum DayState: String, Codable, CaseIterable {
    case noPlan = "NO_PLAN"
    case locked = "LOCKED"
    case allDone = "ALL_DONE"
    case reckoningOpen = "RECKONING_OPEN"
    case reckoned = "RECKONED"
    case autoMissed = "AUTO_MISSED"
}

enum TaskStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case done = "DONE"
    case skipped = "SKIPPED"
}
