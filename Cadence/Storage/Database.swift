import Foundation
import GRDB

enum CadenceDatabase {
    static let shared: DatabaseQueue = {
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = appSupport.appendingPathComponent("Cadence", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbPath = dir.appendingPathComponent("cadence.sqlite").path
            var config = Configuration()
            config.label = "Cadence"
            let queue = try DatabaseQueue(path: dbPath, configuration: config)
            try migrator.migrate(queue)
            return queue
        } catch {
            fatalError("Failed to open Cadence database: \(error)")
        }
    }()

    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()

        m.registerMigration("v1") { db in
            try db.create(table: "days") { t in
                t.primaryKey("date", .text)
                t.column("state", .text).notNull()
                t.column("locked_at", .datetime)
                t.column("reckoned_at", .datetime)
                t.column("reckoning_time", .text).notNull()
            }

            try db.create(table: "tasks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull().references("days", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("status", .text).notNull()
                t.column("done_at", .datetime)
                t.column("skip_reason", .text)
            }

            try db.create(table: "app_state") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }

            try db.execute(sql: "INSERT OR IGNORE INTO app_state (key, value) VALUES ('reckoning_time_default', '18:00')")
            try db.execute(sql: "INSERT OR IGNORE INTO app_state (key, value) VALUES ('launch_at_login', 'true')")
            try db.execute(sql: "INSERT OR IGNORE INTO app_state (key, value) VALUES ('planner_snooze_count', '0')")
        }

        // Drop the streak concept entirely: the days.streak_after column and the
        // current_streak app_state key. The feature was removed as not useful.
        m.registerMigration("v2") { db in
            try db.alter(table: "days") { t in
                t.drop(column: "streak_after")
            }
            try db.execute(sql: "DELETE FROM app_state WHERE key = 'current_streak'")
        }

        return m
    }
}
