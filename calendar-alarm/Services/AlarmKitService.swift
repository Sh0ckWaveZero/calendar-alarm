import AlarmKit
import ActivityKit
import AppIntents
import Foundation
import SwiftUI

// The system supplies the Stop button automatically; these intents make Stop/Snooze
// open the app, matching the original app's launchAppOnDismiss/Snooze behavior.
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var openAppWhenRun = true

    @Parameter(title: "Event")
    var payload: String?

    init() {}
    init(payload: String?) { self.payload = payload }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze"
    static var openAppWhenRun = true

    @Parameter(title: "Event")
    var payload: String?

    init() {}
    init(payload: String?) { self.payload = payload }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Metadata carrier for AlarmKit attributes (kept non-nil, as in the proven wrapper).
struct CalSyncAlarmMetadata: AlarmMetadata {}

/// Thin wrapper around Apple's AlarmKit (iOS 26+). The schedule shape mirrors the
/// proven expo-alarm-kit implementation that rings on this device: fixed-date alarm,
/// explicit stop button, snooze via a countdown secondary button.
protocol AlarmScheduling {
    func requestAlarmAuthorization() async -> Bool
    func scheduleEventAlarm(eventId: UUID, title: String, fireDate: Date, soundName: String?) async throws -> UUID
    func cancelEventAlarm(_ id: UUID) async throws
    func allAlarmIds() throws -> [UUID]
    var authorizationDescription: String { get }
}

@MainActor
final class AlarmKitService: AlarmScheduling {
    static let shared = AlarmKitService()

    /// Original app snoozed for 5 minutes.
    private let snoozeSeconds: TimeInterval = 300

    private init() {
        #if DEBUG
        observeAlarmUpdates()
        #endif
    }

    /// Watches the daemon's alarm stream — proves whether alarms fire system-side.
    #if DEBUG
    private func observeAlarmUpdates() {
        Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                let summary = alarms.map { "\($0.id.uuidString.prefix(6))=\($0.state) fire=\($0.schedule.flatMap { if case .fixed(let d) = $0 { return d.description } else { return nil } } ?? "-")" }
                DebugLog.write("alarmUpdates: \(summary)")
            }
            DebugLog.write("alarmUpdates stream ended")
        }
    }
    #endif

    var authorizationDescription: String {
        "\(AlarmManager.shared.authorizationState)"
    }

    func requestAlarmAuthorization() async -> Bool {
        let before = AlarmManager.shared.authorizationState
        print("[CalSync] auth state before request: \(before)")
        DebugLog.write("auth state before request: \(before)")
        if before == .authorized { return true }
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            print("[CalSync] requestAuthorization -> \(state)")
            DebugLog.write("requestAuthorization -> \(state)")
            return state == .authorized
        } catch {
            print("[CalSync] requestAuthorization FAILED: \(error)")
            DebugLog.write("requestAuthorization FAILED: \(error)")
            return false
        }
    }

    func scheduleEventAlarm(eventId: UUID, title: String, fireDate: Date, soundName: String?) async throws -> UUID {
        let id = UUID()
        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "stop.circle"
        )
        let snoozeButton = AlarmButton(
            text: "Snooze",
            textColor: .white,
            systemImageName: "clock.badge.checkmark"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stopButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .countdown
        )
        let attributes = AlarmAttributes<CalSyncAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: CalSyncAlarmMetadata(),
            tintColor: Color(red: 0.369, green: 0.361, blue: 0.902)
        )
        let sound: AlertConfiguration.AlertSound
        if let soundName, !soundName.isEmpty {
            // The daemon resolves named sounds against Library/Sounds by literal
            // filename — the extension must be included or the lookup returns nil
            // and the alarm falls back to the default sound (verified via
            // SpringBoard's "External sound url" log on the simulator).
            let fileName = soundName.hasSuffix(".caf") ? soundName : "\(soundName).caf"
            sound = .named(fileName)
        } else {
            sound = .default
        }
        let configuration = AlarmManager.AlarmConfiguration<CalSyncAlarmMetadata>(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds),
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: StopAlarmIntent(payload: eventId.uuidString),
            secondaryIntent: SnoozeAlarmIntent(payload: eventId.uuidString),
            sound: sound
        )
        do {
            let alarm = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            print("[CalSync] scheduled id=\(id) fire=\(fireDate) sound=\(soundName ?? "default") state=\(alarm.state)")
            DebugLog.write("scheduled id=\(id.uuidString.prefix(6)) fire=\(fireDate) sound=\(soundName ?? "default") state=\(alarm.state)")
            return id
        } catch {
            print("[CalSync] schedule FAILED: \(error)")
            DebugLog.write("schedule FAILED: \(error)")
            throw error
        }
    }

    func cancelEventAlarm(_ id: UUID) async throws {
        do {
            try AlarmManager.shared.cancel(id: id)
            print("[CalSync] cancelled id=\(id)")
        } catch {
            print("[CalSync] cancel FAILED id=\(id): \(error)")
            throw error
        }
    }

    /// Ground truth of every alarm the daemon holds for this app — used to spot orphans.
    func allAlarmIds() throws -> [UUID] {
        let ids = try AlarmManager.shared.alarms.map(\.id)
        print("[CalSync] native alarms: \(ids.count) -> \(ids.map { $0.uuidString.prefix(6) })")
        return ids
    }
}
