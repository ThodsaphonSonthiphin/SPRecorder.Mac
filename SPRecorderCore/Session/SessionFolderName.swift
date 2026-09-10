import Foundation

/// Names a Session folder (sprecorder-mac-0019): `2026-09-10 Thu 14.30`, or
/// `2026-09-10 Thu 14.30 — Team standup` for a Named session. The rewrite of the Windows
/// `FileNameBuilder` (sprecorder-mac-0003): ICU date letters, macOS character rules.
public enum SessionFolderName {
    public static let defaultTimestampFormat = "yyyy-MM-dd EEE HH.mm"
    public static let maxBytes = 255

    /// Fills `{timestamp:FORMAT}` (or `{timestamp}`) in `pattern`, appends ` — name` when a
    /// session name is given, and makes the result safe as one macOS folder name.
    public static func make(pattern: String, startedAt: Date, sessionName: String? = nil, timeZone: TimeZone = .current) -> String {
        let regex = /\{timestamp(?::([^}]+))?\}/
        var name = pattern.replacing(regex) { match in
            let format = match.output.1.map(String.init) ?? defaultTimestampFormat
            return formatter(format, timeZone).string(from: startedAt)
        }
        if let label = sessionName?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            name += " — " + label
        }
        let clean = sanitize(name)
        return clean.isEmpty ? formatter(defaultTimestampFormat, timeZone).string(from: startedAt) : clean
    }

    /// The macOS rule of sprecorder-mac-0019: `/` and `:` become `-`, leading dots are removed
    /// (a leading dot hides the folder), trailing spaces and dots are trimmed, and the name is
    /// capped at 255 UTF-8 bytes without cutting a character in half.
    public static func sanitize(_ raw: String, maxBytes: Int = SessionFolderName.maxBytes) -> String {
        var s = raw.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        while s.hasPrefix(".") { s.removeFirst() }
        s = capped(s, maxBytes)
        while let last = s.last, last == " " || last == "." { s.removeLast() }
        return s
    }

    /// The folder to create inside `parent`: `name`, or `name (2)`, `name (3)`… when a folder
    /// of that name already exists — Finder's own convention.
    public static func uniqueFolderURL(in parent: URL, name: String, fileManager: FileManager = .default) -> URL {
        var candidate = parent.appendingPathComponent(name, isDirectory: true)
        var n = 2
        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = " (\(n))"
            let base = sanitize(name, maxBytes: maxBytes - suffix.utf8.count)
            candidate = parent.appendingPathComponent(base + suffix, isDirectory: true)
            n += 1
        }
        return candidate
    }

    private static func capped(_ s: String, _ maxBytes: Int) -> String {
        guard s.utf8.count > maxBytes else { return s }
        var out = ""
        var bytes = 0
        for ch in s {
            let size = String(ch).utf8.count
            if bytes + size > maxBytes { break }
            out.append(ch)
            bytes += size
        }
        return out
    }

    /// Pinned to en_US_POSIX and the Gregorian calendar: a Mac set to Thailand would otherwise
    /// write the Buddhist year, 2569 (sprecorder-mac-0019).
    private static func formatter(_ format: String, _ timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }
}
