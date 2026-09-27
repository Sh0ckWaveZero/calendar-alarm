import Foundation
import SwiftData

/// App-wide SwiftData container holding the user's alarms.
@MainActor
enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([AlarmItem.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    static var context: ModelContext {
        container.mainContext
    }
}
