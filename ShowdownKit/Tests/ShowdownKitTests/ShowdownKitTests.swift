import XCTest
@testable import ShowdownKit

final class ProtocolTests: XCTestCase {
    func testFrameWithRoom() {
        let frame = ServerFrame(raw: ">battle-gen9ou-1\n|init|battle\n|title|A vs. B")
        XCTAssertEqual(frame.roomID, "battle-gen9ou-1")
        XCTAssertEqual(frame.lines, ["|init|battle", "|title|A vs. B"])
    }

    func testGlobalFrame() {
        let frame = ServerFrame(raw: "|challstr|4|abc")
        XCTAssertEqual(frame.roomID, "")
        XCTAssertEqual(ProtocolLine(frame.lines[0]).args, ["4|abc"])
    }

    func testKwArgs() {
        let line = ProtocolLine("|-damage|p2a: Raikou|80/100|[from] item: Life Orb")
        XCTAssertEqual(line.kind, "-damage")
        XCTAssertEqual(line.args, ["p2a: Raikou", "80/100"])
        XCTAssertEqual(line.kwArgs["from"], "item: Life Orb")
        let miss = ProtocolLine("|move|p1a: Goodra|Draco Meteor|p2a: Raikou|[miss]")
        XCTAssertEqual(miss.kwArgs["miss"], "")
    }

    func testChatKeepsPipes() {
        let line = ProtocolLine("|c|+Alice|hello | world")
        XCTAssertEqual(line.args, ["+Alice", "hello | world"])
    }

    func testIdentAndDetails() {
        let ident = PokemonIdent("p2b: Mr. Mime")!
        XCTAssertEqual(ident.side, "p2")
        XCTAssertEqual(ident.slot, 1)
        XCTAssertEqual(ident.name, "Mr. Mime")
        let noSlot = PokemonIdent("p1: Goodra")!
        XCTAssertNil(noSlot.slot)
        XCTAssertEqual(noSlot.name, "Goodra")
        let details = PokemonDetails("Rotom-Wash, L83, F, shiny, tera:Electric")
        XCTAssertEqual(details.species, "Rotom-Wash")
        XCTAssertEqual(details.level, 83)
        XCTAssertEqual(details.gender, "F")
        XCTAssertTrue(details.shiny)
        XCTAssertEqual(details.teraType, "Electric")
        let hp = HealthStatus("0 fnt")
        XCTAssertTrue(hp.fainted)
        let par = HealthStatus("231/295 par")
        XCTAssertEqual(par.hp, 231)
        XCTAssertEqual(par.maxHP, 295)
        XCTAssertEqual(par.status, "par")
    }

    func testToID() {
        XCTAssertEqual(toID("Pokémon Showdown!"), "pokmonshowdown")
        XCTAssertEqual(toID("[Gen 9] OU"), "gen9ou")
    }
}

final class FormatTests: XCTestCase {
    func testParsesLiveFormatsList() throws {
        let line = ProtocolLine(try fixture("formats.txt").trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(line.kind, "formats")
        let sections = FormatParser.parse(line.args)
        XCTAssertGreaterThan(sections.count, 3)
        let all = sections.flatMap(\.formats)
        let random = try XCTUnwrap(all.first { $0.id == "gen9randombattle" })
        XCTAssertFalse(random.requiresTeam)
        XCTAssertTrue(random.searchShow)
        XCTAssertEqual(random.section, "S/V Singles")
        let ou = try XCTUnwrap(all.first { $0.id == "gen9ou" })
        XCTAssertTrue(ou.requiresTeam)
        XCTAssertEqual(ou.shortName, "OU")
        XCTAssertEqual(ou.genLabel, "Gen 9")
        XCTAssertTrue(all.first { $0.id == "gen9randomdoublesbattle" }!.isDoubles)
    }
}

final class BattleReplayTests: XCTestCase {
    func replay(_ name: String) throws -> (BattleState, [BattleEvent], [BattleRequest]) {
        var state = BattleState(roomID: "battle-test")
        var events: [BattleEvent] = []
        var requests: [BattleRequest] = []
        for raw in try fixture(name).components(separatedBy: "\n") {
            if raw.hasPrefix("|request|") {
                let request = try XCTUnwrap(BattleRequest.parse(String(raw.dropFirst(9))), raw)
                requests.append(request)
                continue
            }
            events += state.apply(raw)
        }
        return (state, events, requests)
    }

    func testSinglesReplay() throws {
        let (state, events, requests) = try replay("singles.log")
        XCTAssertTrue(state.ended)
        XCTAssertEqual(state.winner, "Alice")
        XCTAssertEqual(state.sides["p1"]?.name, "Alice")
        XCTAssertGreaterThan(state.turn, 5)
        XCTAssertEqual(state.sides["p2"]?.pokemon.count, 6)
        XCTAssertEqual(state.sides["p2"]?.faintedCount, 6)
        XCTAssertTrue(events.contains(.turn(1)))
        XCTAssertTrue(events.contains { if case .faint = $0 { return true }; return false })
        XCTAssertTrue(state.log.contains { $0.text == "Turn 1" })
        XCTAssertTrue(state.log.contains { $0.text.contains("used") })
        XCTAssertTrue(state.sides["p2"]!.conditions.keys.contains("Stealth Rock") || state.log.contains { $0.text.contains("Pointed stones") })
        XCTAssertFalse(requests.isEmpty)
        XCTAssertTrue(requests.contains { $0.kind == .forceSwitch })
        let first = try XCTUnwrap(requests.first { $0.kind == .move })
        XCTAssertEqual(first.active.first?.moves.count, 4)
        XCTAssertEqual(first.side.pokemon.count, 6)
        for side in state.sides.values {
            for mon in side.pokemon {
                XCTAssertGreaterThanOrEqual(mon.hpFraction, 0)
                XCTAssertLessThanOrEqual(mon.hpFraction, 1)
            }
        }
    }

    func testDoublesReplay() throws {
        let (state, _, requests) = try replay("doubles.log")
        XCTAssertEqual(state.gameType, "doubles")
        XCTAssertEqual(state.activesPerSide, 2)
        XCTAssertEqual(state.sides["p1"]?.active.count, 2)
        XCTAssertTrue(state.ended)
        XCTAssertEqual(requests.first { $0.kind == .move }?.active.count, 2)
        XCTAssertTrue(state.fields.contains("Psychic Terrain") || state.log.contains { $0.text.contains("Psychic Terrain") })
    }

    func testPerspectiveNaming() {
        var state = BattleState(roomID: "r")
        state.perspective = "p2"
        state.apply("|player|p1|Alice||")
        state.apply("|player|p2|Bob||")
        state.apply("|switch|p1a: Pikachu|Pikachu, L50|100/100")
        state.apply("|switch|p2a: Eevee|Eevee, L50|120/120")
        state.apply("|move|p2a: Eevee|Tackle|p1a: Pikachu")
        state.apply("|-damage|p1a: Pikachu|60/100")
        XCTAssertTrue(state.log.contains { $0.text == "Eevee used Tackle!" })
        XCTAssertTrue(state.log.contains { $0.text == "Alice sent out Pikachu!" })
        XCTAssertEqual(state.sides["p1"]?.activePokemon(0)?.hpPercent, 60)
        XCTAssertEqual(state.sides["p2"]?.activePokemon(0)?.maxHP, 120)
    }

    func testSplitLinesUsePerspective() {
        var state = BattleState(roomID: "r")
        state.perspective = "p1"
        state.apply("|player|p1|Alice||")
        state.apply("|split|p1")
        state.apply("|switch|p1a: Pikachu|Pikachu, L50|95/95")
        state.apply("|switch|p1a: Pikachu|Pikachu, L50|100/100")
        XCTAssertEqual(state.sides["p1"]?.activePokemon(0)?.maxHP, 95)
        XCTAssertEqual(state.sides["p1"]?.pokemon.count, 1)
    }
}

final class TeamTests: XCTestCase {
    let paste = """
    Ting-Lu @ Leftovers
    Ability: Vessel of Ruin
    Tera Type: Poison
    EVs: 252 HP / 4 Def / 252 SpD
    Careful Nature
    - Stealth Rock
    - Ruination
    - Earthquake
    - Whirlwind

    Speedy (Dragapult) (F) @ Choice Specs
    Ability: Infiltrator
    Shiny: Yes
    Tera Type: Ghost
    EVs: 4 Atk / 252 SpA / 252 Spe
    Timid Nature
    IVs: 0 Atk
    - Shadow Ball
    - Draco Meteor
    - Flamethrower
    - U-turn

    Rotom-Wash @ Sitrus Berry
    Ability: Levitate
    Level: 50
    - Hydro Pump
    - Volt Switch
    """

    func testPackMatchesOfficialImplementation() {
        let sets = TeamText.importSets(paste)
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets[1].nickname, "Speedy")
        XCTAssertEqual(sets[1].species, "Dragapult")
        XCTAssertEqual(sets[1].gender, "F")
        XCTAssertEqual(sets[1].ivs.atk, 0)
        // Output of `Teams.pack(Teams.import(paste))` from the pokemon-showdown package.
        let expected = "Ting-Lu||Leftovers|VesselofRuin|StealthRock,Ruination,Earthquake,Whirlwind|Careful|252,,4,,252,|||||,,,,,Poison]Speedy|Dragapult|ChoiceSpecs|Infiltrator|ShadowBall,DracoMeteor,Flamethrower,Uturn|Timid|,4,,252,,252|F|,0,,,,|S||,,,,,Ghost]Rotom-Wash||SitrusBerry|Levitate|HydroPump,VoltSwitch||||||50|"
        XCTAssertEqual(TeamText.pack(sets), expected)
    }

    func testRoundTrip() {
        let sets = TeamText.importSets(paste)
        let again = TeamText.importSets(TeamText.export(sets))
        XCTAssertEqual(TeamText.pack(again), TeamText.pack(sets))
    }

    func testBackupImport() {
        let backup = "=== [gen9ou] Folder/Rain ===\n\n" + paste + "\n\n=== [gen9uu] Second ===\n\nPikachu\n- Thunderbolt\n"
        let teams = TeamText.importTeams(backup)
        XCTAssertEqual(teams.count, 2)
        XCTAssertEqual(teams[0].name, "Rain")
        XCTAssertEqual(teams[0].format, "gen9ou")
        XCTAssertEqual(teams[0].pokemon.count, 3)
        XCTAssertEqual(teams[1].format, "gen9uu")
    }

    func testStats() {
        // Garchomp 252 Atk Jolly L100: 359 Atk; HP base 108 with 0 EVs: 357
        XCTAssertEqual(StatCalculator.stat("atk", base: 130, iv: 31, ev: 252, level: 100, nature: "Jolly"), 359)
        XCTAssertEqual(StatCalculator.stat("hp", base: 108, iv: 31, ev: 0, level: 100, nature: "Jolly"), 357)
    }
}

final class DexTests: XCTestCase {
    func testSpriteIDHeuristics() {
        XCTAssertEqual(Sprites.spriteID("Rotom-Wash"), "rotom-wash")
        XCTAssertEqual(Sprites.spriteID("Ho-Oh"), "hooh")
        XCTAssertEqual(Sprites.spriteID("Mr. Mime"), "mrmime")
        XCTAssertEqual(Sprites.spriteID("Ogerpon-Wellspring"), "ogerpon-wellspring")
        XCTAssertEqual(Sprites.spriteID("Urshifu-*"), "urshifu")
        XCTAssertEqual(Sprites.spriteID("Tapu Koko"), "tapukoko")
    }

    func testTypeChart() {
        XCTAssertEqual(TypeChart.multiplier(attack: "Electric", defenders: ["Water", "Flying"]), 4)
        XCTAssertEqual(TypeChart.multiplier(attack: "Ground", defenders: ["Electric", "Flying"]), 0)
        XCTAssertEqual(TypeChart.multiplier(attack: "Fire", defenders: ["Water"]), 0.5)
    }

    func testNameTable() {
        let js = #"exports.BattleItems = {abilityshield:{name:"Ability Shield",spritenum:746},leftovers:{name:"Leftovers",num:234}};"#
        let table = DexData.parseNameTable(js)
        XCTAssertEqual(table["leftovers"], "Leftovers")
        XCTAssertEqual(table["abilityshield"], "Ability Shield")
    }
}

func fixture(_ name: String) throws -> String {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
    return try String(contentsOf: url, encoding: .utf8)
}
