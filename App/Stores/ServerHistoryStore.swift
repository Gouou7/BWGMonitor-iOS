import BWGMonitorShared
import Foundation
import SQLite3

actor ServerHistoryStore {
    enum HistoryError: Error, LocalizedError {
        case openFailed
        case statementFailed(String)

        var errorDescription: String? {
            switch self {
            case .openFailed:
                return "Failed to open the server history database."
            case let .statementFailed(message):
                return message
            }
        }
    }

    func upsertHistorySamples(for serviceID: String, samples: [UsageSample], retentionDays: Int) throws {
        guard !samples.isEmpty else {
            try pruneHistory(for: serviceID, retentionDays: retentionDays)
            return
        }

        let db = try openDatabase(for: serviceID)
        defer { sqlite3_close(db) }

        try ensureSchema(in: db)
        try execute("BEGIN IMMEDIATE TRANSACTION;", in: db)
        do {
            try upsertParsedHistory(samples, in: db)
            try execute("COMMIT;", in: db)
        } catch {
            try? execute("ROLLBACK;", in: db)
            throw error
        }

        try pruneHistory(for: serviceID, retentionDays: retentionDays)
    }

    func upsertCurrentSample(for serviceID: String, sample: UsageSample, retentionDays: Int) throws {
        let db = try openDatabase(for: serviceID)
        defer { sqlite3_close(db) }

        try ensureSchema(in: db)
        try execute("BEGIN IMMEDIATE TRANSACTION;", in: db)
        do {
            try upsertCurrentSample(sample, in: db)
            try execute("COMMIT;", in: db)
        } catch {
            try? execute("ROLLBACK;", in: db)
            throw error
        }

        try pruneHistory(for: serviceID, retentionDays: retentionDays)
    }

    private func upsertParsedHistory(_ samples: [UsageSample], in db: OpaquePointer?) throws {
        let sql = """
        INSERT INTO usage_samples (
            timestamp,
            cpu_usage_percent,
            bandwidth_used_bytes
        ) VALUES (?, ?, ?)
        ON CONFLICT(timestamp) DO UPDATE SET
            cpu_usage_percent = excluded.cpu_usage_percent,
            bandwidth_used_bytes = excluded.bandwidth_used_bytes;
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryError.statementFailed("Failed to prepare parsed history statement.")
        }

        defer { sqlite3_finalize(statement) }

        for sample in samples.sorted(by: { $0.timestamp < $1.timestamp }) {
            sqlite3_bind_double(statement, 1, sample.timestamp.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, sample.cpuUsagePercent)
            sqlite3_bind_int64(statement, 3, sample.bandwidthUsedBytes)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw HistoryError.statementFailed("Failed to write parsed server history.")
            }

            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
    }

    private func upsertCurrentSample(_ sample: UsageSample, in db: OpaquePointer?) throws {
        let sql = """
        INSERT INTO usage_samples (
            timestamp,
            cpu_usage_percent,
            bandwidth_used_bytes,
            bandwidth_total_bytes,
            bandwidth_remaining_bytes,
            memory_used_bytes,
            memory_total_bytes,
            swap_used_bytes,
            swap_total_bytes,
            disk_used_bytes,
            disk_total_bytes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(timestamp) DO UPDATE SET
            cpu_usage_percent = excluded.cpu_usage_percent,
            bandwidth_used_bytes = excluded.bandwidth_used_bytes,
            bandwidth_total_bytes = excluded.bandwidth_total_bytes,
            bandwidth_remaining_bytes = excluded.bandwidth_remaining_bytes,
            memory_used_bytes = excluded.memory_used_bytes,
            memory_total_bytes = excluded.memory_total_bytes,
            swap_used_bytes = excluded.swap_used_bytes,
            swap_total_bytes = excluded.swap_total_bytes,
            disk_used_bytes = excluded.disk_used_bytes,
            disk_total_bytes = excluded.disk_total_bytes;
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryError.statementFailed("Failed to prepare current sample statement.")
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, sample.timestamp.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, sample.cpuUsagePercent)
        sqlite3_bind_int64(statement, 3, sample.bandwidthUsedBytes)
        sqlite3_bind_int64(statement, 4, sample.bandwidthTotalBytes)
        sqlite3_bind_int64(statement, 5, sample.bandwidthRemainingBytes)
        sqlite3_bind_int64(statement, 6, sample.memoryUsedBytes)
        sqlite3_bind_int64(statement, 7, sample.memoryTotalBytes)
        sqlite3_bind_int64(statement, 8, sample.swapUsedBytes)
        sqlite3_bind_int64(statement, 9, sample.swapTotalBytes)
        sqlite3_bind_int64(statement, 10, sample.diskUsedBytes)
        sqlite3_bind_int64(statement, 11, sample.diskTotalBytes)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryError.statementFailed("Failed to write the current usage sample.")
        }
    }

    func loadHistory(for serviceID: String) throws -> [UsageSample] {
        let db = try openDatabase(for: serviceID)
        defer { sqlite3_close(db) }

        try ensureSchema(in: db)
        return try loadHistory(in: db)
    }

    private func loadHistory(in db: OpaquePointer?) throws -> [UsageSample] {
        let sql = """
        SELECT
            timestamp,
            cpu_usage_percent,
            bandwidth_used_bytes,
            bandwidth_total_bytes,
            bandwidth_remaining_bytes,
            memory_used_bytes,
            memory_total_bytes,
            swap_used_bytes,
            swap_total_bytes,
            disk_used_bytes,
            disk_total_bytes
        FROM usage_samples
        ORDER BY timestamp ASC;
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryError.statementFailed("Failed to prepare history query.")
        }

        defer { sqlite3_finalize(statement) }

        var samples: [UsageSample] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let timestamp = sqlite3_column_double(statement, 0)
            let cpu = sqlite3_column_double(statement, 1)
            let bandwidth = sqlite3_column_int64(statement, 2)
            let bandwidthTotal = sqlite3_column_int64(statement, 3)
            let bandwidthRemaining = sqlite3_column_int64(statement, 4)
            let memoryUsed = sqlite3_column_int64(statement, 5)
            let memoryTotal = sqlite3_column_int64(statement, 6)
            let swapUsed = sqlite3_column_int64(statement, 7)
            let swapTotal = sqlite3_column_int64(statement, 8)
            let diskUsed = sqlite3_column_int64(statement, 9)
            let diskTotal = sqlite3_column_int64(statement, 10)

            samples.append(
                UsageSample(
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    cpuUsagePercent: cpu,
                    bandwidthUsedBytes: bandwidth,
                    bandwidthTotalBytes: bandwidthTotal,
                    bandwidthRemainingBytes: bandwidthRemaining,
                    memoryUsedBytes: memoryUsed,
                    memoryTotalBytes: memoryTotal,
                    swapUsedBytes: swapUsed,
                    swapTotalBytes: swapTotal,
                    diskUsedBytes: diskUsed,
                    diskTotalBytes: diskTotal
                )
            )
        }

        return samples
    }

    func pruneHistory(for serviceID: String, retentionDays: Int) throws {
        let db = try openDatabase(for: serviceID)
        defer { sqlite3_close(db) }

        try ensureSchema(in: db)
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-retentionDays * 86_400)).timeIntervalSince1970
        let sql = "DELETE FROM usage_samples WHERE timestamp < ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryError.statementFailed("Failed to prepare prune statement.")
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, cutoff)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryError.statementFailed("Failed to prune old history.")
        }
    }

    func clearHistory(for serviceID: String) throws {
        let db = try openDatabase(for: serviceID)
        defer { sqlite3_close(db) }

        try ensureSchema(in: db)
        try execute("DELETE FROM usage_samples;", in: db)
    }

    func deleteStorage(for serviceID: String) throws {
        let directoryURL = AppSupportPaths.serverDirectoryURL(serviceID: serviceID)
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
    }

    private func openDatabase(for serviceID: String) throws -> OpaquePointer? {
        var database: OpaquePointer?
        let url = AppSupportPaths.serverHistoryDatabaseURL(serviceID: serviceID)

        guard sqlite3_open(url.path, &database) == SQLITE_OK else {
            if let database {
                sqlite3_close(database)
            }
            throw HistoryError.openFailed
        }

        return database
    }

    private func ensureSchema(in db: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS usage_samples (
            timestamp REAL PRIMARY KEY,
            cpu_usage_percent REAL NOT NULL,
            bandwidth_used_bytes INTEGER NOT NULL,
            bandwidth_total_bytes INTEGER NOT NULL DEFAULT 0,
            bandwidth_remaining_bytes INTEGER NOT NULL DEFAULT 0,
            memory_used_bytes INTEGER NOT NULL DEFAULT 0,
            memory_total_bytes INTEGER NOT NULL DEFAULT 0,
            swap_used_bytes INTEGER NOT NULL DEFAULT 0,
            swap_total_bytes INTEGER NOT NULL DEFAULT 0,
            disk_used_bytes INTEGER NOT NULL DEFAULT 0,
            disk_total_bytes INTEGER NOT NULL DEFAULT 0
        );
        """

        try execute(sql, in: db)
        try ensureColumn(named: "bandwidth_total_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "bandwidth_remaining_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "memory_used_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "memory_total_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "swap_used_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "swap_total_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "disk_used_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
        try ensureColumn(named: "disk_total_bytes", definition: "INTEGER NOT NULL DEFAULT 0", in: db)
    }

    private func ensureColumn(named column: String, definition: String, in db: OpaquePointer?) throws {
        let pragma = "PRAGMA table_info(usage_samples);"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, pragma, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryError.statementFailed("Failed to inspect server history schema.")
        }

        defer { sqlite3_finalize(statement) }

        var existingColumns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1).map({ String(cString: $0) }) {
                existingColumns.insert(name)
            }
        }

        guard !existingColumns.contains(column) else {
            return
        }

        try execute("ALTER TABLE usage_samples ADD COLUMN \(column) \(definition);", in: db)
    }
    private func execute(_ sql: String, in db: OpaquePointer?) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            let message = sqlite3_errmsg(db).map(String.init(cString:)) ?? "Unknown SQLite error."
            throw HistoryError.statementFailed(message)
        }
    }
}
