import Foundation
import ShowdownKit

/// Offline content for previews and screenshots: launch with `-demoBattle` or `-demoTeams`.
enum DemoContent {
    static let battleRoom = "battle-gen9ou-demo"

    static let battleIntro = """
    |init|battle
    |title|You vs. Cynthia
    |player|p1|You|lucas|
    |player|p2|Cynthia|cynthia|1650
    |teamsize|p1|6
    |teamsize|p2|6
    |gametype|singles
    |gen|9
    |tier|[Gen 9] OU
    |start
    |switch|p1a: Dragapult|Dragapult, F|317/317
    |switch|p2a: Garchomp|Garchomp, M|100/100
    |turn|1
    """

    static let battleTurn = """
    |move|p1a: Dragapult|Draco Meteor|p2a: Garchomp
    |-supereffective|p2a: Garchomp
    |-damage|p2a: Garchomp|38/100
    |-unboost|p1a: Dragapult|spa|2
    |move|p2a: Garchomp|Stealth Rock|p1a: Dragapult
    |-sidestart|p1: You|move: Stealth Rock
    |-weather|Sandstorm|[from] ability: Sand Stream|[of] p2a: Garchomp
    |-damage|p1a: Dragapult|281/317|[from] Sandstorm
    |turn|2
    """

    static let battleRequest = #"""
    {"active":[{"moves":[{"move":"Draco Meteor","id":"dracometeor","pp":7,"maxpp":8,"target":"normal","disabled":false},{"move":"Shadow Ball","id":"shadowball","pp":24,"maxpp":24,"target":"normal","disabled":false},{"move":"U-turn","id":"uturn","pp":32,"maxpp":32,"target":"normal","disabled":false},{"move":"Will-O-Wisp","id":"willowisp","pp":24,"maxpp":24,"target":"normal","disabled":false}],"canTerastallize":"Ghost"}],"side":{"name":"You","id":"p1","pokemon":[{"ident":"p1: Dragapult","details":"Dragapult, F","condition":"281/317","active":true,"stats":{"atk":276,"def":186,"spa":328,"spd":186,"spe":421},"moves":["dracometeor","shadowball","uturn","willowisp"],"baseAbility":"infiltrator","item":"choicespecs","teraType":"Ghost","terastallized":""},{"ident":"p1: Kingambit","details":"Kingambit, M","condition":"341/341","active":false,"stats":{"atk":369,"def":276,"spa":156,"spd":206,"spe":122},"moves":["swordsdance","kowtowcleave","suckerpunch","ironhead"],"baseAbility":"supremeoverlord","item":"leftovers","teraType":"Dark","terastallized":""},{"ident":"p1: Gholdengo","details":"Gholdengo","condition":"317/317","active":false,"stats":{"atk":136,"def":226,"spa":367,"spd":236,"spe":293},"moves":["makeitrain","shadowball","nastyplot","recover"],"baseAbility":"goodasgold","item":"airballoon","teraType":"Steel","terastallized":""},{"ident":"p1: Great Tusk","details":"Great Tusk","condition":"435/435","active":false,"stats":{"atk":397,"def":296,"spa":127,"spd":175,"spe":309},"moves":["headlongrush","icespinner","rapidspin","knockoff"],"baseAbility":"protosynthesis","item":"boosterenergy","teraType":"Ground","terastallized":""},{"ident":"p1: Corviknight","details":"Corviknight, F","condition":"399/399","active":false,"stats":{"atk":208,"def":309,"spa":127,"spd":206,"spe":170},"moves":["bravebird","uturn","roost","defog"],"baseAbility":"pressure","item":"rockyhelmet","teraType":"Dragon","terastallized":""},{"ident":"p1: Iron Valiant","details":"Iron Valiant","condition":"181/290","active":false,"stats":{"atk":266,"def":216,"spa":372,"spd":256,"spe":366},"moves":["moonblast","psyshock","calmmind","encore"],"baseAbility":"quarkdrive","item":"boosterenergy","teraType":"Fairy","terastallized":""}]},"rqid":3}
    """#

    static let sampleTeam = """
    === [gen9ou] Sand Offense ===

    Garchomp @ Rocky Helmet
    Ability: Rough Skin
    Tera Type: Steel
    EVs: 252 HP / 4 Def / 252 Spe
    Jolly Nature
    - Stealth Rock
    - Earthquake
    - Dragon Tail
    - Spikes

    Dragapult (F) @ Choice Specs
    Ability: Infiltrator
    Tera Type: Ghost
    EVs: 252 SpA / 4 SpD / 252 Spe
    Timid Nature
    - Draco Meteor
    - Shadow Ball
    - U-turn
    - Flamethrower

    Kingambit @ Leftovers
    Ability: Supreme Overlord
    Tera Type: Dark
    EVs: 252 HP / 252 Atk / 4 SpD
    Adamant Nature
    - Swords Dance
    - Kowtow Cleave
    - Sucker Punch
    - Iron Head

    Gholdengo @ Air Balloon
    Ability: Good as Gold
    Tera Type: Steel
    EVs: 252 SpA / 4 SpD / 252 Spe
    Timid Nature
    - Make It Rain
    - Shadow Ball
    - Nasty Plot
    - Recover

    Great Tusk @ Booster Energy
    Ability: Protosynthesis
    Tera Type: Ground
    EVs: 252 Atk / 4 SpD / 252 Spe
    Jolly Nature
    - Headlong Rush
    - Ice Spinner
    - Rapid Spin
    - Knock Off

    Iron Valiant @ Booster Energy
    Ability: Quark Drive
    Tera Type: Fairy
    EVs: 252 SpA / 4 SpD / 252 Spe
    Timid Nature
    - Moonblast
    - Psyshock
    - Calm Mind
    - Encore
    """
}

extension AppModel {
    func startDemos() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoTeams") || arguments.contains("-demoBattle"), teams.teams.isEmpty {
            teams.importText(DemoContent.sampleTeam, format: "gen9ou")
        }
        if arguments.contains("-demoBattle") {
            let battle = BattleController(roomID: DemoContent.battleRoom, app: self)
            battle.myUserID = "you"
            battles.append(battle)
            presentedBattle = battle
            battle.receive(DemoContent.battleIntro.components(separatedBy: "\n"), instant: true)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                battle.receive(["|request|" + DemoContent.battleRequest], instant: false)
                battle.receive(DemoContent.battleTurn.components(separatedBy: "\n"), instant: false)
            }
        }
    }
}
