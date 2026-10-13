import Foundation

/// Human-readable battle messages, modeled on the in-game text.
public enum BattleText {
    public static let statNames: [String: String] = [
        "atk": "Attack", "def": "Defense", "spa": "Sp. Atk", "spd": "Sp. Def",
        "spe": "Speed", "accuracy": "accuracy", "evasion": "evasiveness",
    ]

    public static let statusNames: [String: String] = [
        "brn": "burn", "par": "paralysis", "slp": "sleep", "frz": "freeze", "psn": "poison", "tox": "poison",
    ]

    /// `move: Stealth Rock` -> `Stealth Rock`, `item: Leftovers` -> `Leftovers`.
    public static func effectName(_ text: String) -> String {
        for prefix in ["move: ", "ability: ", "item: ", "condition: "] where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }

    public static func weatherName(_ id: String) -> String {
        switch id {
        case "RainDance": return "Rain"
        case "SunnyDay": return "Harsh Sunlight"
        case "Sandstorm": return "Sandstorm"
        case "Hail": return "Hail"
        case "Snow", "Snowscape": return "Snow"
        case "DesolateLand": return "Extremely Harsh Sunlight"
        case "PrimordialSea": return "Heavy Rain"
        case "DeltaStream": return "Strong Winds"
        default: return id
        }
    }

    static func weatherStart(_ id: String) -> String {
        switch id {
        case "RainDance": return "It started to rain!"
        case "SunnyDay": return "The sunlight turned harsh!"
        case "Sandstorm": return "A sandstorm kicked up!"
        case "Hail": return "It started to hail!"
        case "Snow", "Snowscape": return "It started to snow!"
        case "DesolateLand": return "The sunlight turned extremely harsh!"
        case "PrimordialSea": return "A heavy rain began to fall!"
        case "DeltaStream": return "Mysterious strong winds are protecting Flying-type Pokémon!"
        default: return "\(weatherName(id)) began!"
        }
    }

    static func weatherUpkeep(_ id: String) -> String {
        switch id {
        case "RainDance": return "Rain continues to fall."
        case "SunnyDay": return "The sunlight is strong."
        case "Sandstorm": return "The sandstorm is raging."
        case "Hail": return "The hail is crashing down."
        case "Snow", "Snowscape": return "The snow continues to fall."
        default: return "\(weatherName(id)) continues."
        }
    }

    static func weatherEnd(_ id: String) -> String {
        switch id {
        case "RainDance": return "The rain stopped."
        case "SunnyDay": return "The harsh sunlight faded."
        case "Sandstorm": return "The sandstorm subsided."
        case "Hail": return "The hail stopped."
        case "Snow", "Snowscape": return "The snow stopped."
        default: return "The weather cleared up."
        }
    }

    static func status(_ name: String, status: String) -> String {
        switch status {
        case "brn": return "\(name) was burned!"
        case "par": return "\(name) is paralyzed! It may be unable to move!"
        case "slp": return "\(name) fell asleep!"
        case "frz": return "\(name) was frozen solid!"
        case "psn": return "\(name) was poisoned!"
        case "tox": return "\(name) was badly poisoned!"
        default: return "\(name) is affected by \(status)."
        }
    }

    static func cureStatus(_ name: String, status: String) -> String {
        switch status {
        case "slp": return "\(name) woke up!"
        case "frz": return "\(name) thawed out!"
        case "par": return "\(name) was cured of paralysis."
        case "brn": return "\(name)'s burn was healed."
        case "psn", "tox": return "\(name) was cured of its poisoning."
        default: return "\(name)'s status returned to normal."
        }
    }

    static func cant(_ name: String, reason: String, move: String) -> String {
        switch effectName(reason) {
        case "slp": return "\(name) is fast asleep."
        case "par": return "\(name) is paralyzed! It can't move!"
        case "frz": return "\(name) is frozen solid!"
        case "flinch": return "\(name) flinched and couldn't move!"
        case "recharge": return "\(name) must recharge!"
        case "Taunt": return "\(name) can't use \(move) after the taunt!"
        case "Disable": return "\(name)'s \(move) is disabled!"
        case "Truant": return "\(name) is loafing around!"
        case "nopp": return "\(name) has no PP left for \(move)!"
        default: return "\(name) can't move!"
        }
    }

    static func boost(_ name: String, stat: String, amount: Int) -> String {
        let statName = statNames[stat] ?? stat
        switch amount {
        case 0: return "\(name)'s \(statName) won't go any \(stat.isEmpty ? "further" : "higher")!"
        case 1: return "\(name)'s \(statName) rose!"
        case 2: return "\(name)'s \(statName) rose sharply!"
        case 3...: return "\(name)'s \(statName) rose drastically!"
        case -1: return "\(name)'s \(statName) fell!"
        case -2: return "\(name)'s \(statName) harshly fell!"
        default: return "\(name)'s \(statName) severely fell!"
        }
    }

    static func sideStart(_ effect: String, foe: Bool) -> String {
        let team = foe ? "the opposing team" : "your team"
        switch effect {
        case "Stealth Rock": return "Pointed stones float in the air around \(team)!"
        case "Spikes": return "Spikes were scattered on the ground all around \(team)!"
        case "Toxic Spikes": return "Poison spikes were scattered on the ground all around \(team)!"
        case "Sticky Web": return "A sticky web has been laid out on the ground around \(team)!"
        case "Reflect": return "Reflect made \(team) stronger against physical moves!"
        case "Light Screen": return "Light Screen made \(team) stronger against special moves!"
        case "Aurora Veil": return "Aurora Veil made \(team) stronger against physical and special moves!"
        case "Tailwind": return "The Tailwind blew from behind \(team)!"
        case "Safeguard": return "\(team.prefix(1).uppercased() + team.dropFirst()) cloaked itself in a mystical veil!"
        default: return "\(effect) started on \(team)'s side!"
        }
    }

    static func volatileStart(_ name: String, effect: String) -> String {
        switch effect {
        case "Substitute": return "\(name) put in a substitute!"
        case "confusion": return "\(name) became confused!"
        case "Taunt": return "\(name) fell for the taunt!"
        case "Encore": return "\(name) received an encore!"
        case "Leech Seed": return "\(name) was seeded!"
        case "Yawn": return "\(name) grew drowsy!"
        case "Disable": return "\(name)'s move was disabled!"
        case "perish3", "perish2", "perish1", "perish0": return "\(name)'s perish count fell to \(effect.last.map(String.init) ?? "0")."
        case "Focus Energy": return "\(name) is getting pumped!"
        case "Salt Cure": return "\(name) is being salt cured!"
        default:
            if effect.hasPrefix("quarkdrive") || effect.hasPrefix("protosynthesis") {
                return "\(name)'s \(statNames[String(effect.suffix(3))] ?? "stat") was heightened!"
            }
            return "\(name): \(effect)"
        }
    }

    static func volatileEnd(_ name: String, effect: String) -> String {
        switch effect {
        case "Substitute": return "\(name)'s substitute faded!"
        case "confusion": return "\(name) snapped out of its confusion!"
        case "Taunt": return "\(name) shook off the taunt!"
        case "Encore": return "\(name)'s encore ended!"
        default: return "\(name)'s \(effect) ended."
        }
    }

    static func singleTurn(_ name: String, effect: String) -> String? {
        switch effect {
        case "Protect", "Detect", "King's Shield", "Spiky Shield", "Baneful Bunker", "Silk Trap", "Burning Bulwark", "Obstruct", "Max Guard":
            return "\(name) protected itself!"
        case "Endure": return "\(name) braced itself!"
        case "Roost": return nil
        case "Focus Punch": return "\(name) is tightening its focus!"
        case "Helping Hand": return "\(name) is ready to help!"
        case "Follow Me", "Rage Powder": return "\(name) became the center of attention!"
        default: return nil
        }
    }

    static func activate(_ name: String, effect: String) -> String? {
        switch effect {
        case "Protect", "Detect", "King's Shield", "Spiky Shield", "Baneful Bunker", "Silk Trap", "Burning Bulwark", "Obstruct", "Max Guard":
            return "\(name) protected itself!"
        case "Substitute": return "The substitute took damage for \(name)!"
        case "confusion": return "\(name) is confused!"
        case "Endure": return "\(name) endured the hit!"
        case "Focus Sash", "Sturdy": return "\(name) hung on!"
        case "Destiny Bond": return "\(name) took its attacker down with it!"
        case "Trick", "Switcheroo": return "\(name) switched items!"
        default: return nil
        }
    }

    static func damageFrom(_ name: String, from: String, of source: String?) -> String {
        let effect = effectName(from)
        switch effect {
        case "brn": return "\(name) was hurt by its burn!"
        case "psn", "tox": return "\(name) was hurt by poison!"
        case "Stealth Rock": return "Pointed stones dug into \(name)!"
        case "Spikes": return "\(name) was hurt by the spikes!"
        case "Sandstorm": return "\(name) is buffeted by the sandstorm!"
        case "Hail": return "\(name) is buffeted by the hail!"
        case "Recoil", "recoil": return "\(name) was damaged by the recoil!"
        case "Life Orb": return "\(name) lost some of its HP!"
        case "confusion": return "It hurt itself in its confusion!"
        case "Leech Seed": return "\(name)'s health is sapped by Leech Seed!"
        case "Rocky Helmet", "Rough Skin", "Iron Barbs": return "\(name) was hurt by \(source.map { "\($0)'s " } ?? "")\(effect)!"
        case "Salt Cure": return "\(name) is hurt by Salt Cure!"
        case "Black Sludge", "Sticky Barb": return "\(name) was hurt by its \(effect)!"
        default: return "\(name) was hurt by \(effect)!"
        }
    }

    static func healFrom(_ name: String, from: String) -> String {
        let effect = effectName(from)
        switch effect {
        case "Leftovers", "Black Sludge", "Shell Bell": return "\(name) restored a little HP using its \(effect)!"
        case "drain": return "\(name) had its energy drained!"
        case "Grassy Terrain": return "\(name)'s HP was restored by the Grassy Terrain."
        case "Leech Seed": return "\(name) restored HP with Leech Seed."
        case "Regenerator": return "\(name) regenerated."
        default:
            if from.hasPrefix("item: ") { return "\(name) restored HP using its \(effect)!" }
            if from.hasPrefix("ability: ") { return "\(name) restored HP using its \(effect)!" }
            return "\(name) had its HP restored."
        }
    }

    static func item(_ name: String, item: String, from: String?) -> String {
        guard let from else { return "\(name) is holding \(item)." }
        let effect = effectName(from)
        switch effect {
        case "Trick", "Switcheroo": return "\(name) obtained one \(item)."
        case "Frisk": return "\(name) was frisked and found to be holding \(item)!"
        default: return "\(name) obtained \(item)."
        }
    }

    static func endItem(_ name: String, item: String, eaten: Bool, from: String?) -> String {
        if eaten { return "\(name) ate its \(item)!" }
        if let from {
            let effect = effectName(from)
            if effect == "Knock Off" { return "\(name)'s \(item) was knocked off!" }
            if effect == "stealeat" { return "\(name)'s \(item) was stolen and eaten!" }
            return "\(name) lost its \(item)!"
        }
        switch item {
        case "Focus Sash": return "\(name) hung on using its Focus Sash!"
        case "Air Balloon": return "\(name)'s Air Balloon popped!"
        case "Booster Energy": return "\(name) used its Booster Energy to activate its ability!"
        default: return "\(name)'s \(item) was used up."
        }
    }

    public static func stripHTML(_ html: String) -> String {
        var out = ""
        var inTag = false
        for ch in html {
            if ch == "<" { inTag = true; continue }
            if ch == ">" { inTag = false; continue }
            if !inTag { out.append(ch) }
        }
        return out
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&rarr;", with: "→")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
