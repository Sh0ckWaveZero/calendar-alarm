import Foundation
import Observation
import SwiftData

/// One day-section of the alarms list.
struct AlarmSection: Identifiable {
    let dayStart: Date
    let items: [AlarmItem]
    var id: Date { dayStart }
}

@MainActor
final class AlarmsViewModel: ObservableObject {
    @Published private(set) var sections: [AlarmSection] = []
    @Published var isLoading = true
    @Published var saveErrorMessage: String?
    @Published var alarmPermissionDenied = false

    let scheduler: AlarmScheduling
    private let context: ModelContext

    init(context: ModelContext? = nil, scheduler: AlarmScheduling? = nil) {
        self.context = context ?? Persistence.context
        self.scheduler = scheduler ?? AlarmKitService.shared
    }

    // MARK: - Loading

    /// Loads from a single snapshot: purges fired alarms from earlier days, cancels
    /// orphaned native alarms, then rebuilds the sections.
    func load() async {
        SoundCatalog.ensureInstalled()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let all = fetchAll()
        #if DEBUG
        print("[CalSync] load: \(all.count) items \(all.map { "\($0.time) alarmId=\($0.alarmId?.uuidString.prefix(6) ?? "nil")" })")
        #endif

        let stale = all.filter { $0.time < startOfToday }
        for item in stale {
            if let alarmId = item.alarmId {
                try? await scheduler.cancelEventAlarm(alarmId)
            }
            context.delete(item)
        }
        if !stale.isEmpty { try? context.save() }

        let nativeIds = (try? scheduler.allAlarmIds()) ?? []
        if !nativeIds.isEmpty {
            let ownedIds = Set(all.compactMap(\.alarmId))
            for id in nativeIds where !ownedIds.contains(id) {
                try? await scheduler.cancelEventAlarm(id)
            }
        }

        reloadSections(from: all.filter { $0.time >= startOfToday })
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    private func reloadSections(from upcoming: [AlarmItem]) {
        let grouped = Dictionary(grouping: upcoming) { item in
            Calendar.current.startOfDay(for: item.time)
        }
        sections = grouped
            .map { AlarmSection(dayStart: $0.key, items: $0.value.sorted { $0.time < $1.time }) }
            .sorted { $0.dayStart < $1.dayStart }
    }

    private func reloadSections() {
        reloadSections(from: fetchAll().filter { $0.time >= Calendar.current.startOfDay(for: Date()) })
    }

    /// Fetches every alarm, oldest first. (Filtering happens in memory — SwiftData
    /// predicates crash on a container that has never been written to.)
    private func fetchAll() -> [AlarmItem] {
        let descriptor = FetchDescriptor<AlarmItem>(sortBy: [SortDescriptor(\.time)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Adding / editing

    /// Creates an alarm that fires at the next occurrence of the picked time-of-day.
    func addAlarm(timeOfDay: Date, soundName: String? = nil) async {
        let item = AlarmItem(time: DateUtil.nextOccurrence(of: timeOfDay), soundName: soundName)
        context.insert(item)
        try? context.save()
        await schedule(item)
        reloadSections()
    }

    /// Reschedules an existing alarm, keeping its day and applying the picked time-of-day and sound.
    func updateAlarm(_ item: AlarmItem, timeOfDay: Date, soundName: String? = nil) async {
        let newTime = DateUtil.combine(day: item.time, timeOfDay: timeOfDay)
        guard newTime != item.time || soundName != item.soundName else { return }
        if let oldId = item.alarmId {
            try? await scheduler.cancelEventAlarm(oldId)
            item.alarmId = nil
        }
        item.time = newTime
        item.soundName = soundName
        try? context.save()
        await schedule(item)
        reloadSections()
    }

    func deleteAlarm(_ item: AlarmItem) async {
        if let alarmId = item.alarmId {
            try? await scheduler.cancelEventAlarm(alarmId)
        }
        context.delete(item)
        try? context.save()
        reloadSections()
    }

    private func schedule(_ item: AlarmItem) async {
        guard item.time > Date() else {
            print("[CalSync] skip schedule: fire time already passed (\(item.time))")
            return
        }
        guard await scheduler.requestAlarmAuthorization() else {
            print("[CalSync] schedule aborted: authorization denied")
            alarmPermissionDenied = true
            return
        }
        do {
            item.alarmId = try await scheduler.scheduleEventAlarm(
                eventId: item.id,
                title: Self.alertTitle(for: item),
                fireDate: item.time,
                soundName: item.soundName
            )
            try? context.save()
            print("[CalSync] item saved with alarmId=\(item.alarmId?.uuidString.prefix(6) ?? "nil")")
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    /// Title shown on the system alarm UI: "Alarm 7:00 AM".
    static func alertTitle(for item: AlarmItem) -> String {
        let timeText = item.time.formatted(date: .omitted, time: .shortened)
        return String(localized: "Alarm \(timeText)")
    }

    // MARK: - DEBUG demo harness (launch arguments for simulator smoke tests)

    #if DEBUG
    /// Self-test: schedules an alarm two minutes from now (launch with -demoSelfTest).
    func debugSelfTest() {
        let fire = Date().addingTimeInterval(120)
        let item = AlarmItem(time: fire)
        context.insert(item)
        try? context.save()
        print("[CalSync] self-test alarm scheduled in app at \(fire)")
        DebugLog.write("self-test alarm created fire=\(fire)")
        Task {
            await schedule(item)
            reloadSections()
        }
        startDebugTicker()
    }

    /// Schedules three probe alarms 90s apart with different sound-name variants
    /// so the daemon's resolution behavior can be compared in one pass.
    func debugSoundTest() {
        let probes: [(offset: TimeInterval, sound: String?, tag: String)] = [
            (90, "alarm-chime", "bundled-noext"),
            (150, "alarm-chime.caf", "bundled-ext"),
            (210, "alarm", "system-alarm"),
        ]
        for probe in probes {
            let fire = Date().addingTimeInterval(probe.offset)
            let item = AlarmItem(time: fire, soundName: probe.sound)
            context.insert(item)
            try? context.save()
            DebugLog.write("soundTest probe \(probe.tag) sound=\(probe.sound ?? "nil") fire=\(fire)")
            Task {
                await schedule(item)
                reloadSections()
            }
        }
        startDebugTicker()
    }

    /// Logs daemon state every 30s for 10 minutes so fire-time behavior lands in the log file.
    func startDebugTicker() {
        Task { [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self, !Task.isCancelled else { return }
                let native = (try? scheduler.allAlarmIds()) ?? []
                DebugLog.write("tick now=\(Date()) native=\(native.map { $0.uuidString.prefix(6) })")
            }
        }
    }

    func seedSampleAlarms() {
        guard (try? context.fetchCount(FetchDescriptor<AlarmItem>())) == 0 else { return }
        let calendar = Calendar.current
        let tonight = DateUtil.nextOccurrence(of: Date().addingTimeInterval(5400))
        let sevenAM = DateUtil.nextOccurrence(of: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date())
        let noon1230 = DateUtil.nextOccurrence(of: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: Date()) ?? Date())

        let seeded = [
            AlarmItem(time: tonight, alarmId: UUID()),
            AlarmItem(time: sevenAM, alarmId: UUID()),
            AlarmItem(time: noon1230, alarmId: UUID()),
        ]
        for item in seeded {
            context.insert(item)
        }
        try? context.save()
        reloadSections()
    }
    #endif
}
