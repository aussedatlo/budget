import BudgetCore
import Foundation
import SQLite3

/// The SwiftData store of the versions before the shared core. Its rows are
/// read once, without changing the file, and moved into the shared database
/// (see `LegacyImport` in the shared core). The file is left where it is.
enum LegacyStore {
    /// Where SwiftData kept the data by default.
    static var url: URL { URL.applicationSupportDirectory.appending(path: "default.store") }

    /// Moves the earlier data over, the first time the new version opens.
    static func importIfNeeded(into repository: BudgetRepository) {
        guard !LegacyImport.shared.isDone(repository: repository) else { return }
        guard FileManager.default.fileExists(atPath: url.path), let rows = SQLiteRows(path: url.path) else {
            LegacyImport.shared.skip(repository: repository)
            return
        }
        _ = LegacyImport.shared.run(repository: repository, rows: rows)
    }
}

/// Every row of a table of an SQLite file, as text (see `LegacyRows`).
private final class SQLiteRows: NSObject, LegacyRows {
    private var db: OpaquePointer?

    init?(path: String) {
        // Read-write so SQLite can read the pending changes of its WAL file;
        // nothing is written
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
    }

    deinit { sqlite3_close(db) }

    func rows(table: String) -> [[String: String]] {
        // Table names come from the shared core, never from the user
        guard table.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT * FROM \(table)", -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return [] // no such table
        }
        defer { sqlite3_finalize(statement) }

        var result: [[String: String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                guard let name = sqlite3_column_name(statement, index).map({ String(cString: $0) }) else { continue }
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER:
                    row[name] = String(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT:
                    row[name] = String(sqlite3_column_double(statement, index))
                case SQLITE_TEXT:
                    row[name] = sqlite3_column_text(statement, index).map { String(cString: $0) }
                case SQLITE_BLOB:
                    let count = Int(sqlite3_column_bytes(statement, index))
                    if let bytes = sqlite3_column_blob(statement, index) {
                        row[name] = String(data: Data(bytes: bytes, count: count), encoding: .utf8)
                    }
                default:
                    break // NULL
                }
            }
            result.append(row)
        }
        return result
    }
}
