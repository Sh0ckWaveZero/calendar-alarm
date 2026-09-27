import XCTest
import SwiftData
@testable import calendar_alarm

@MainActor
private func makeWorld() throws -> (ModelContainer, AlarmsViewModel, FakeScheduler) {
    let schema = Schema([AlarmItem.self])
    // On-disk store in a unique temp directory — mirrors the real app configuration.
    // (Fetching on a never-written in-memory container traps inside SwiftData on iOS.)
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("calendar-alarm-tests-\(UUID().uuidString)")
        .appendingPathExtension("store")
    let configuration = ModelConfiguration(schema: schema, url: storeURL)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    let scheduler = FakeScheduler()
    let viewModel = AlarmsViewModel(context: context, scheduler: scheduler)
    return (container, viewModel, scheduler)
}

@MainActor
final class FakeScheduler: AlarmScheduling {
    var authorized = true
    private(set) var scheduled: [(eventId: UUID, title: String, fireDate: Date, soundName: String?, id: UUID)] = []
    private(set) var cancelled: [UUID] = []
    var nativeIds: [UUID] = []

    var authorizationDescription: String { authorized ? "authorized" : "denied" }

    func requestAlarmAuthorization() async -> Bool { authorized }

    func scheduleEventAlarm(eventId: UUID, title: String, fireDate: Date, soundName: String?) async throws -> UUID {
        let id = UUID()
        scheduled.append((eventId, title, fireDate, soundName, id))
        return id
    }

    func cancelEventAlarm(_ id: UUID) async throws {
        cancelled.append(id)
    }

    func allAlarmIds() throws -> [UUID] { nativeIds }
}

@MainActor
final class AlarmsViewModelTests: XCTestCase {

    // MARK: - Time resolution

    func testNextOccurrenceIsTodayWhenStillAhead() {
        let now = dateAt(hour: 10, minute: 0)
        let picked = dateAt(hour: 22, minute: 30)
        let result = DateUtil.nextOccurrence(of: picked, from: now)
        XCTAssertEqual(Calendar.current.startOfDay(for: result), Calendar.current.startOfDay(for: now))
        XCTAssertEqual(Calendar.current.component(.hour, from: result), 22)
        XCTAssertEqual(Calendar.current.component(.minute, from: result), 30)
        XCTAssertEqual(Calendar.current.component(.second, from: result), 0)
    }

    func testNextOccurrenceRollsToTomorrowWhenPassed() {
        let now = dateAt(hour: 23, minute: 0)
        let picked = dateAt(hour: 7, minute: 0)
        let result = DateUtil.nextOccurrence(of: picked, from: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        XCTAssertEqual(Calendar.current.startOfDay(for: result), tomorrow)
        XCTAssertEqual(Calendar.current.component(.hour, from: result), 7)
    }

    func testCombineKeepsDayOfExistingAlarm() {
        let day = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let timeOfDay = dateAt(hour: 9, minute: 15)
        let combined = DateUtil.combine(day: day, timeOfDay: timeOfDay)
        XCTAssertEqual(Calendar.current.startOfDay(for: combined), Calendar.current.startOfDay(for: day))
        XCTAssertEqual(Calendar.current.component(.hour, from: combined), 9)
        XCTAssertEqual(Calendar.current.component(.minute, from: combined), 15)
    }

    // MARK: - Add / edit / delete

    func testAddAlarmSchedulesAtNextOccurrenceAndStoresHandle() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 7, minute: 0))

        XCTAssertEqual(scheduler.scheduled.count, 1)
        let items = try container.mainContext.fetch(FetchDescriptor<AlarmItem>())
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.alarmId, scheduler.scheduled.first?.id)
        XCTAssertTrue(item.isArmed)
        let scheduledFire = try XCTUnwrap(scheduler.scheduled.first?.fireDate)
        XCTAssertEqual(scheduledFire, item.time)
        XCTAssertTrue(scheduledFire > Date())
    }

    func testAddAlarmWithoutAuthorizationLeavesUnscheduled() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container
        scheduler.authorized = false

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 7, minute: 0))

        XCTAssertTrue(scheduler.scheduled.isEmpty)
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)
        XCTAssertNil(item.alarmId)
        XCTAssertFalse(item.isArmed)
        XCTAssertTrue(viewModel.alarmPermissionDenied)
    }

    func testUpdateAlarmCancelsOldAndSchedulesNew() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 7, minute: 0))
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)
        let oldAlarmId = try XCTUnwrap(item.alarmId)
        let oldDay = Calendar.current.startOfDay(for: item.time)

        await viewModel.updateAlarm(item, timeOfDay: dateAt(hour: 9, minute: 45))

        XCTAssertTrue(scheduler.cancelled.contains(oldAlarmId))
        XCTAssertEqual(scheduler.scheduled.count, 2)
        XCTAssertEqual(item.alarmId, scheduler.scheduled.last?.id)
        // The day is preserved, only the time-of-day changed.
        XCTAssertEqual(Calendar.current.startOfDay(for: item.time), oldDay)
        XCTAssertEqual(Calendar.current.component(.hour, from: item.time), 9)
        XCTAssertEqual(Calendar.current.component(.minute, from: item.time), 45)
    }

    func testAddAlarmPassesSoundNameThrough() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 7, minute: 0), soundName: "alarm-chime")

        XCTAssertEqual(scheduler.scheduled.first?.soundName, "alarm-chime")
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)
        XCTAssertEqual(item.soundName, "alarm-chime")
    }

    func testUpdateAlarmChangesSoundAndReschedules() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 7, minute: 0))
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)
        let oldAlarmId = try XCTUnwrap(item.alarmId)
        let countBefore = scheduler.scheduled.count

        await viewModel.updateAlarm(item, timeOfDay: dateAt(hour: 7, minute: 0), soundName: "alarm-beep")

        XCTAssertTrue(scheduler.cancelled.contains(oldAlarmId))
        XCTAssertEqual(scheduler.scheduled.count, countBefore + 1)
        XCTAssertEqual(scheduler.scheduled.last?.soundName, "alarm-beep")
        XCTAssertEqual(item.soundName, "alarm-beep")
    }

    func testDeleteAlarmCancelsNativeAlarm() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 7, minute: 0))
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)
        let alarmId = try XCTUnwrap(item.alarmId)

        await viewModel.deleteAlarm(item)

        XCTAssertTrue(scheduler.cancelled.contains(alarmId))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).isEmpty)
    }

    // MARK: - Load-time cleanup

    func testLoadPurgesAlarmsFromEarlierDays() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let stale = AlarmItem(time: yesterday, alarmId: UUID())
        container.mainContext.insert(stale)
        try container.mainContext.save()

        await viewModel.load()

        XCTAssertTrue(scheduler.cancelled.contains(try XCTUnwrap(stale.alarmId)))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).isEmpty)
    }

    func testLoadCancelsOrphanNativeAlarms() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        let orphanId = UUID()
        scheduler.nativeIds = [orphanId]

        await viewModel.load()

        XCTAssertTrue(scheduler.cancelled.contains(orphanId))
    }

    func testLoadKeepsUpcomingAlarms() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        await viewModel.addAlarm(timeOfDay: dateAt(hour: 22, minute: 0))
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)

        await viewModel.load()

        XCTAssertFalse(scheduler.cancelled.contains(try XCTUnwrap(item.alarmId)))
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(viewModel.sections.first?.items.first?.id, item.id)
    }

    // MARK: - Calendar day helpers

    func testAddAlarmWithExplicitDayFiresOnThatDay() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        let futureDay = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        await viewModel.addAlarm(timeOfDay: dateAt(hour: 6, minute: 15), day: futureDay)

        let fire = try XCTUnwrap(scheduler.scheduled.first?.fireDate)
        XCTAssertEqual(Calendar.current.startOfDay(for: fire), Calendar.current.startOfDay(for: futureDay))
        XCTAssertEqual(Calendar.current.component(.hour, from: fire), 6)
        XCTAssertEqual(Calendar.current.component(.minute, from: fire), 15)
    }

    func testAddAlarmTodayWithPassedTimeSkipsScheduling() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = container

        let passed = Date().addingTimeInterval(-3600)
        await viewModel.addAlarm(timeOfDay: passed, day: Calendar.current.startOfDay(for: Date()))

        XCTAssertTrue(scheduler.scheduled.isEmpty)
        let item = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<AlarmItem>()).first)
        XCTAssertNil(item.alarmId)
    }

    func testItemsOnDayFiltersAndSorts() async throws {
        let (container, viewModel, scheduler) = try makeWorld()
        _ = scheduler

        let day = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 5, to: Date())!)
        let evening = DateUtil.combine(day: day, timeOfDay: dateAt(hour: 22, minute: 0))
        let morning = DateUtil.combine(day: day, timeOfDay: dateAt(hour: 8, minute: 0))
        container.mainContext.insert(AlarmItem(time: evening, alarmId: UUID()))
        container.mainContext.insert(AlarmItem(time: morning, alarmId: UUID()))
        try container.mainContext.save()

        await viewModel.load()

        let onDay = viewModel.items(on: day)
        XCTAssertEqual(onDay.count, 2)
        XCTAssertEqual(onDay.first?.time, morning)
        XCTAssertEqual(onDay.last?.time, evening)
        XCTAssertEqual(viewModel.daysWithAlarms, [day])
        XCTAssertTrue(viewModel.items(on: Calendar.current.date(byAdding: .day, value: 6, to: day)!).isEmpty)
    }

    // MARK: - Helpers

    private func dateAt(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
}
