import Foundation

enum TripRecordNaming {
    /// Mặc định: `Record_` + timestamp (POSIX, ổn định cho tên file / sort).
    static func defaultRecordName(completedAt: Date = .init()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return "Record_\(f.string(from: completedAt))"
    }
}
