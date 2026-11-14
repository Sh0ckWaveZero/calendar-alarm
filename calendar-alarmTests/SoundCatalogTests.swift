import AVFoundation
import XCTest
@testable import calendar_alarm

final class SoundCatalogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sound-catalog-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeSilence(named name: String, seconds: Double, in folder: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1))
        let file = try AVAudioFile(forWriting: folder.appendingPathComponent(name), settings: format.settings)
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        try file.write(from: buffer)
    }

    func testSystemSoundsListsAlarmLengthSoundsWithPrefixedIds() throws {
        try writeSilence(named: "Radar_Classic.caf", seconds: 2, in: directory)
        try writeSilence(named: "key_press_click.caf", seconds: 0.1, in: directory)
        try "not audio".write(to: directory.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let sounds = SoundCatalog.systemSounds(in: [(directory, .ringtone)])

        XCTAssertEqual(sounds.map(\.id), ["ios-Radar_Classic"])
        XCTAssertEqual(sounds.first?.label, "Radar Classic")
        XCTAssertEqual(sounds.first?.source, .ringtone)
    }

    func testSystemSoundsKeepsFirstDirectoryWhenNamesCollide() throws {
        let first = directory.appendingPathComponent("first", isDirectory: true)
        let second = directory.appendingPathComponent("second", isDirectory: true)
        for folder in [first, second] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try writeSilence(named: "Chord.caf", seconds: 2, in: folder)
        }

        let sounds = SoundCatalog.systemSounds(in: [(first, .ringtone), (second, .systemSound)])

        XCTAssertEqual(sounds.map(\.source), [.ringtone])
    }

    func testLabelForBundledAndSystemIds() {
        XCTAssertEqual(SoundCatalog.label(for: "alarm-chime"), "Chime")
        XCTAssertEqual(SoundCatalog.label(for: "ios-sms-received1"), "sms received1")
    }
}
