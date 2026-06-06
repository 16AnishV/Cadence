import Foundation
import GRDB

struct DailyTask: Codable, Equatable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "tasks"

    var id: Int64?
    var date: String
    var position: Int
    var title: String
    var status: TaskStatus
    var doneAt: Date?
    var skipReason: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case position
        case title
        case status
        case doneAt = "done_at"
        case skipReason = "skip_reason"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let date = Column(CodingKeys.date)
        static let position = Column(CodingKeys.position)
        static let title = Column(CodingKeys.title)
        static let status = Column(CodingKeys.status)
        static let doneAt = Column(CodingKeys.doneAt)
        static let skipReason = Column(CodingKeys.skipReason)
    }
}
