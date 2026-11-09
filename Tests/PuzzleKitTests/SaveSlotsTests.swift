import Foundation
import Testing
@testable import PuzzleKit

@MainActor
struct SaveSlotsTests {
    enum Mode: Hashable, Sendable { case standard, daily, scratch }
    struct Game: Codable, Equatable { var moves: Int }

    private func freshDefaults() -> UserDefaults {
        let name = "SaveSlotsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let keys: [Mode: String] = [.standard: "game.save.v1", .daily: "game.save.daily.v1"]

    @Test func slotsDoNotOverwriteEachOther() {
        let slots = SaveSlots<Mode, Game>(defaults: freshDefaults(), keys: keys)
        slots.save(Game(moves: 7), in: .standard, hasProgress: true)
        slots.save(Game(moves: 2), in: .daily, hasProgress: true)
        #expect(slots[.standard] == Game(moves: 7))
        #expect(slots[.daily] == Game(moves: 2))
    }

    @Test func aVisitWithoutProgressKeepsTheOldSave() {
        let slots = SaveSlots<Mode, Game>(defaults: freshDefaults(), keys: keys)
        slots.save(Game(moves: 7), in: .standard, hasProgress: true)
        #expect(!slots.save(Game(moves: 0), in: .standard, hasProgress: false))
        #expect(slots[.standard] == Game(moves: 7))
    }

    @Test func survivesARelaunchAndClearRemovesTheKey() {
        let defaults = freshDefaults()
        let slots = SaveSlots<Mode, Game>(defaults: defaults, keys: keys)
        slots.save(Game(moves: 3), in: .daily, hasProgress: true)
        #expect(SaveSlots<Mode, Game>(defaults: defaults, keys: keys)[.daily] == Game(moves: 3))
        slots.clear(.daily)
        #expect(defaults.data(forKey: "game.save.daily.v1") == nil)
        #expect(SaveSlots<Mode, Game>(defaults: defaults, keys: keys)[.daily] == nil)
    }

    @Test func moveMigratesALegacySave() {
        let defaults = freshDefaults()
        let slots = SaveSlots<Mode, Game>(defaults: defaults, keys: keys)
        slots.save(Game(moves: 4), in: .standard, hasProgress: true)
        slots.move(from: .standard, to: .daily)
        #expect(slots[.standard] == nil)
        #expect(defaults.data(forKey: "game.save.v1") == nil)
        #expect(SaveSlots<Mode, Game>(defaults: defaults, keys: keys)[.daily] == Game(moves: 4))
    }

    @Test func undecodableDataIsIgnoredNotFatal() {
        let defaults = freshDefaults()
        defaults.set(Data("not json".utf8), forKey: "game.save.v1")
        let slots = SaveSlots<Mode, Game>(defaults: defaults, keys: keys)
        #expect(slots[.standard] == nil)
    }

    @Test func aSlotWithoutAKeyLivesInMemory() {
        let defaults = freshDefaults()
        let slots = SaveSlots<Mode, Game>(defaults: defaults, keys: keys)
        slots.save(Game(moves: 1), in: .scratch, hasProgress: true)
        #expect(slots[.scratch] == Game(moves: 1))
        #expect(SaveSlots<Mode, Game>(defaults: defaults, keys: keys)[.scratch] == nil)
    }
}
