import AVFoundation
import Foundation

/// A sound an alarm can ring with. `id` is the value stored in
/// `AlarmItem.soundName` and the base name of its file in Library/Sounds.
struct AlarmSound: Identifiable, Hashable {
    enum Source: CaseIterable {
        case bundled, ringtone, systemSound
    }

    let id: String
    let label: String
    let source: Source
    /// Playable source file (bundle resource or iOS system file).
    let url: URL
}

/// The user's default sound for new alarms (Settings); nil = system default.
enum AlarmDefaults {
    static let soundKey = "defaultSoundName"

    static var soundName: String? {
        let value = UserDefaults.standard.string(forKey: soundKey)
        return value?.isEmpty == false ? value : nil
    }
}

/// Alarm sounds offered in the picker: the bundled ones plus the sounds that
/// ship with iOS. AlarmKit only resolves named sounds from the app bundle and
/// Library/Sounds, so an iOS sound is copied there the first time it is used.
enum SoundCatalog {
    static let systemPrefix = "ios-"

    private static let bundledNames: [(file: String, label: String)] = [
        ("alarm-chime", "Chime"),
        ("alarm-beep", "Beep"),
        ("alarm-rise", "Rise"),
    ]

    static var bundled: [AlarmSound] {
        bundledNames.compactMap { entry in
            guard let url = Bundle.main.url(forResource: entry.file, withExtension: "caf") else { return nil }
            return AlarmSound(id: entry.file, label: entry.label, source: .bundled, url: url)
        }
    }

    /// Where iOS keeps its own sounds. The simulator mirrors the same layout
    /// under its runtime root.
    static var systemDirectories: [(url: URL, source: AlarmSound.Source)] {
        let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] ?? ""
        let paths: [(String, AlarmSound.Source)] = [
            ("/Library/Ringtones", .ringtone),
            ("/System/Library/Audio/UISounds/New", .systemSound),
            ("/System/Library/Audio/UISounds/Modern", .systemSound),
            ("/System/Library/Audio/UISounds", .systemSound),
        ]
        return paths.map { (URL(fileURLWithPath: root + $0.0, isDirectory: true), $0.1) }
    }

    private static let systemExtensions: Set<String> = ["caf", "m4r", "m4a"]

    /// Sounds shorter than this are UI clicks, not something to wake up to.
    private static let minimumDuration: TimeInterval = 1

    /// Scanned once; opens every file header, so call it off the main thread.
    static let system: [AlarmSound] = systemSounds(in: systemDirectories)

    static func systemSounds(
        in directories: [(url: URL, source: AlarmSound.Source)],
        fileManager: FileManager = .default
    ) -> [AlarmSound] {
        var seen = Set<String>()
        var result: [AlarmSound] = []
        for directory in directories {
            let files = (try? fileManager.contentsOfDirectory(at: directory.url, includingPropertiesForKeys: nil)) ?? []
            let sounds = files
                .filter { systemExtensions.contains($0.pathExtension.lowercased()) }
                .filter { duration(of: $0) >= minimumDuration }
                .map { url -> AlarmSound in
                    let id = systemPrefix + url.deletingPathExtension().lastPathComponent
                    return AlarmSound(id: id, label: label(for: id), source: directory.source, url: url)
                }
                .filter { seen.insert($0.id).inserted }
                .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            result.append(contentsOf: sounds)
        }
        return result
    }

    private static func duration(of url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url), file.fileFormat.sampleRate > 0 else { return 0 }
        return Double(file.length) / file.fileFormat.sampleRate
    }

    static func label(for id: String) -> String {
        if let entry = bundledNames.first(where: { $0.file == id }) { return entry.label }
        guard id.hasPrefix(systemPrefix) else { return id }
        return id.dropFirst(systemPrefix.count)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static var soundsDirectory: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    /// Copies the bundled sounds into Library/Sounds.
    static func ensureInstalled() {
        for entry in bundledNames { install(entry.file) }
    }

    /// Makes sure `<id>.caf` exists in Library/Sounds. Safe to call repeatedly;
    /// an id whose source file is gone is left alone and the alarm falls back
    /// to the default sound.
    static func install(_ id: String) {
        let fm = FileManager.default
        guard let soundsDirectory, let source = sourceURL(for: id) else { return }
        try? fm.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        // CAF is the format AlarmKit reliably resolves; WAV never plays.
        let destination = soundsDirectory.appendingPathComponent("\(id).caf")
        if fm.fileExists(atPath: destination.path) { return }
        do {
            if source.pathExtension.lowercased() == "caf" {
                try fm.copyItem(at: source, to: destination)
            } else {
                try convertToCAF(from: source, to: destination)
            }
        } catch {
            try? fm.removeItem(at: destination)
            DebugLog.write("sound install FAILED id=\(id): \(error)")
        }
    }

    private static func sourceURL(for id: String) -> URL? {
        if !id.hasPrefix(systemPrefix) {
            return Bundle.main.url(forResource: id, withExtension: "caf")
        }
        let baseName = String(id.dropFirst(systemPrefix.count))
        for directory in systemDirectories {
            for ext in systemExtensions {
                let candidate = directory.url.appendingPathComponent("\(baseName).\(ext)")
                if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }

    /// Ringtones ship as AAC (.m4r); decode them to 16-bit PCM in a CAF container.
    private static func convertToCAF(from source: URL, to destination: URL) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let output = try AVAudioFile(
            forWriting: destination,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ],
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_768) else { return }
        while input.framePosition < input.length {
            try input.read(into: buffer)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
        }
    }
}
