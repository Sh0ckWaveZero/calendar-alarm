import Foundation

/// DEBUG-only diagnostics written to Documents/caldebug.log so device state
/// can be inspected from the Mac via `devicectl device copy from`.
enum DebugLog {
    static func write(_ message: String) {
        #if DEBUG
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)\n"
        let url = fileURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            try? handle.close()
        }
        #endif
    }

    static func fileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("caldebug.log")
    }
}
