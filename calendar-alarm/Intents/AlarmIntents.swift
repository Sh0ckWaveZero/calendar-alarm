import AppIntents
import SwiftData

/// Siri voice commands for the alarm app ("เฮ้ Siri ตั้งปลุก 6 โมงใน calendar-alarm").
/// The phrases are registered in both English and Thai via AppShortcutsProvider —
/// no manual Shortcuts setup is required on the device.
struct CreateAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Alarm"
    static var description = IntentDescription("Create a new alarm at a time you say.")

    @Parameter(title: "Time", requestValueDialog: IntentDialog("What time should the alarm be for?"))
    var time: Date

    // Injectable for unit tests; production paths use the app's real store and scheduler.
    var context: ModelContext?
    var scheduler: (any AlarmScheduling)?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let viewModel = AlarmsViewModel(
            context: context ?? Persistence.context,
            scheduler: scheduler ?? AlarmKitService.shared
        )
        await viewModel.addAlarm(timeOfDay: time)
        let timeText = time.formatted(date: .omitted, time: .shortened)
        return .result(dialog: IntentDialog("Alarm set for \(timeText)"))
    }
}

/// "เปิด calendar-alarm" — opens the app on the alarm list.
struct OpenAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Alarms"
    static var description = IntentDescription("Open the alarm list.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct CalendarAlarmShortcuts: AppShortcutsProvider {
    // App Shortcut phrases can't interpolate Date parameters (only
    // AppEntity/AppEnum), so the time is requested by Siri via the intent's
    // requestValueDialog instead of being spoken in the phrase.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateAlarmIntent(),
            phrases: [
                "Set an alarm in \(.applicationName)",
                "Create an alarm in \(.applicationName)",
                "ตั้งปลุกใน \(.applicationName)",
                "สร้างการปลุกใน \(.applicationName)",
            ],
            shortTitle: "Set Alarm",
            systemImageName: "alarm"
        )
        AppShortcut(
            intent: OpenAlarmsIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show my alarms in \(.applicationName)",
                "เปิด \(.applicationName)",
                "ดูการปลุกใน \(.applicationName)",
            ],
            shortTitle: "Open Alarms",
            systemImageName: "list.bullet"
        )
    }
}
