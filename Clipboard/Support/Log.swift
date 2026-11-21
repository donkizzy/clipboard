import os

/// Unified-logging categories. Clipboard contents are never logged.
enum Log {
    private static let subsystem = "com.amosgodwin.Clipboard"

    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let panel = Logger(subsystem: subsystem, category: "panel")
}
