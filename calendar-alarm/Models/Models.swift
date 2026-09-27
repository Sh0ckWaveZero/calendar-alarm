import Foundation
import SwiftData

/// One alarm the user set: just a fire time and its native AlarmKit handle.
@Model
final class AlarmItem {
    @Attribute(.unique) var id: UUID
    /// Absolute fire date (one-shot).
    var time: Date
    /// Native AlarmKit alarm UUID; nil while not scheduled.
    var alarmId: UUID?
    /// Bundled sound name (e.g. "alarm-chime"); nil = system default sound.
    var soundName: String?
    var createdAt: Date

    init(id: UUID = UUID(), time: Date, alarmId: UUID? = nil, soundName: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.time = time
        self.alarmId = alarmId
        self.soundName = soundName
        self.createdAt = createdAt
    }

    /// Armed = a native alarm exists and the time is still ahead.
    var isArmed: Bool {
        alarmId != nil && time > Date()
    }
}
