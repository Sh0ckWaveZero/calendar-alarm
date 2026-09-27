import Foundation

/// The bundled alarm sounds offered in the picker.
enum SoundCatalog {
    static let sounds: [(file: String, label: String)] = [
        ("alarm-chime", "Chime"),
        ("alarm-beep", "Beep"),
        ("alarm-rise", "Rise"),
    ]

    static func label(for fileName: String) -> String {
        sounds.first { $0.file == fileName }?.label ?? fileName
    }

    /// Copies bundled sounds into the app's Library/Sounds directory — AlarmKit
    /// looks there (and in the bundle root) when resolving named sounds.
    static func ensureInstalled() {
        let fm = FileManager.default
        guard let soundsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Sounds", isDirectory: true) else { return }
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        for (file, _) in sounds {
            // CAF is the format AlarmKit reliably resolves; WAV never plays.
            let destination = soundsDir.appendingPathComponent("\(file).caf")
            if fm.fileExists(atPath: destination.path) { continue }
            if let bundled = Bundle.main.url(forResource: file, withExtension: "caf") {
                try? fm.copyItem(at: bundled, to: destination)
            }
        }
    }
}
