import XCTest
import SwiftData
@testable import calendar_alarm

/// Exercises CreateAlarmIntent's perform path with an injected context and
/// FakeScheduler — same code Siri runs, minus the real AlarmKit daemon.
@MainActor
final class AlarmIntentsTests: XCTestCase {

    private func makeWorld() throws -> (ModelContainer, FakeScheduler) {
        let schema = Schema([AlarmItem.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("alarm-intents-tests-\(UUID().uuidString)")
            .appendingPathExtension("store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, FakeScheduler())
    }

    func testPerformCreatesAlarmAtSpokenTime() async throws {
        let (container, scheduler) = try makeWorld()
        var intent = CreateAlarmIntent()
        intent.time = dateAt(hour: 6, minute: 30)
        intent.context = container.mainContext
        intent.scheduler = scheduler

        let result = try await intent.perform()

        XCTAssertEqual(scheduler.scheduled.count, 1)
        let fire = try XCTUnwrap(scheduler.scheduled.first?.fireDate)
        XCTAssertTrue(fire > Date())
        XCTAssertEqual(Calendar.current.component(.hour, from: fire), 6)
        XCTAssertEqual(Calendar.current.component(.minute, from: fire), 30)
        let items = try container.mainContext.fetch(FetchDescriptor<AlarmItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.alarmId, scheduler.scheduled.first?.id)
        _ = result
    }

    func testPerformWithoutAuthorizationLeavesUnscheduled() async throws {
        let (container, scheduler) = try makeWorld()
        scheduler.authorized = false
        var intent = CreateAlarmIntent()
        intent.time = dateAt(hour: 7, minute: 0)
        intent.context = container.mainContext
        intent.scheduler = scheduler

        _ = try await intent.perform()

        XCTAssertTrue(scheduler.scheduled.isEmpty)
        let items = try container.mainContext.fetch(FetchDescriptor<AlarmItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items.first?.alarmId)
    }

    private func dateAt(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
}
