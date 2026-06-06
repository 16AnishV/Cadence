import Foundation
import GRDB

struct Day: Codable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "days"

    var date: String
    var state: DayState
    var lockedAt: Date?
    var reckonedAt: Date?
    var reckoningTime: String
    var streakAfter: Int?

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let state = Column(CodingKeys.state)
        static let lockedAt = Column(CodingKeys.lockedAt)
        static let reckonedAt = Column(CodingKeys.reckonedAt)
        static let reckoningTime = Column(CodingKeys.reckoningTime)
        static let streakAfter = Column(CodingKeys.streakAfter)
    }

    enum CodingKeys: String, CodingKey {
        case date
        case state
        case lockedAt = "locked_at"
        case reckonedAt = "reckoned_at"
        case reckoningTime = "reckoning_time"
        case streakAfter = "streak_after"
    }
}
