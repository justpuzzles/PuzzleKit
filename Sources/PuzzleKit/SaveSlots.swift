import Foundation
import Observation

/// Saved games, one per slot, so the modes of a game stop overwriting each
/// other: opening today's daily no longer replaces the standard game you were
/// halfway through, and the other way round.
///
/// Two rules, both from bugs every game shipped at least once:
/// - **Nothing is written for a visit with no progress.** Opening a board and
///   backing out used to save the empty board over Continue. `save` takes
///   `hasProgress:` and keeps the slot's existing snapshot when it is false.
/// - **The snapshots are observable state**, not UserDefaults reads, so a view
///   that shows a Continue card updates the moment a game is saved.
///
/// Each slot has its own UserDefaults key, chosen by the game, so an existing
/// single-slot key can simply become one of the slots.
@Observable @MainActor
public final class SaveSlots<Slot: Hashable & Sendable, Snapshot: Codable> {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keys: [Slot: String]
    public private(set) var snapshots: [Slot: Snapshot] = [:]

    /// `keys` maps every slot to its UserDefaults key. A slot without a key
    /// can still be used, it just lives only in memory.
    public init(defaults: UserDefaults = .standard, keys: [Slot: String]) {
        self.defaults = defaults
        self.keys = keys
        for (slot, key) in keys {
            if let data = defaults.data(forKey: key),
               let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
                snapshots[slot] = snapshot
            }
        }
    }

    public subscript(slot: Slot) -> Snapshot? { snapshots[slot] }

    /// Saves `snapshot` into `slot`, unless `hasProgress` is false, in which
    /// case the slot keeps what it had. Returns whether it wrote.
    @discardableResult
    public func save(_ snapshot: Snapshot, in slot: Slot, hasProgress: Bool) -> Bool {
        guard hasProgress else { return false }
        snapshots[slot] = snapshot
        if let key = keys[slot], let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
        return true
    }

    public func clear(_ slot: Slot) {
        snapshots[slot] = nil
        if let key = keys[slot] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Moves a snapshot to another slot. For one-off migrations, e.g. a
    /// single legacy save that turns out to belong to the daily slot.
    public func move(from source: Slot, to destination: Slot) {
        guard let snapshot = snapshots[source] else { return }
        clear(source)
        save(snapshot, in: destination, hasProgress: true)
    }
}
