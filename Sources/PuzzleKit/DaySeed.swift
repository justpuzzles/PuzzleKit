/// Deterministic seeds for daily puzzles: every player gets the same board.
///
/// Each game hashes its own prefix (`"kakuro.daily.v1."`, `"hashi.daily.v1."`
/// …) followed by `DayKey.isoString`. **The prefix, the hash and the date
/// format are shipped API:** changing any of them rewrites every player's past
/// and future dailies. Each game pins a whole golden board in its tests.
public enum DaySeed {
    /// 64-bit FNV-1a over the UTF-8 bytes of `text`.
    public static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// FNV-1a over `prefix + day.isoString`.
    public static func seed(prefix: String, day: DayKey) -> UInt64 {
        fnv1a(prefix + day.isoString)
    }
}
