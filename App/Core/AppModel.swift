import Foundation
import Observation
import SwiftUI
import ShowdownKit

struct Challenge: Identifiable, Hashable {
    var id: String { user + format }
    var user: String
    var format: String
}

@Observable
@MainActor
final class AppModel {
    static let defaultServer = "wss://sim3.psim.us/showdown/websocket"

    // Connection
    var connectionState: ShowdownConnection.State = .disconnected

    // Account
    var username = ""
    var isNamed = false
    var avatar = ""
    var loginInProgress = false
    var loginError: String?
    var isRegisteredLogin = false

    // Lobby
    var formatSections: [FormatSection] = []
    var searching: [String] = []
    var incomingChallenges: [Challenge] = []
    var outgoingChallenge: Challenge?

    // Battles
    var battles: [BattleController] = []
    var presentedBattle: BattleController?

    var alertMessage: String?

    let dex = DexStore()
    let teams = TeamStore()

    private let connection = ShowdownConnection()
    @ObservationIgnored private var challstr: String?
    @ObservationIgnored private var reconnectAttempts = 0
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var inForeground = true
    /// Battles we've seen this session; used to rejoin after a reconnect.
    @ObservationIgnored private var knownGames: Set<String> = []
    @ObservationIgnored private var pendingNamedAction: (() -> Void)?

    var userID: String { toID(username) }

    var allFormats: [BattleFormat] { formatSections.flatMap(\.formats) }

    func format(id: String) -> BattleFormat? {
        allFormats.first { $0.id == id }
    }

    var serverURL: URL {
        let stored = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        return URL(string: stored.isEmpty ? Self.defaultServer : stored) ?? URL(string: Self.defaultServer)!
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        connection.onFrame = { [weak self] frame in self?.handle(frame) }
        connection.onStateChange = { [weak self] state in self?.connectionChanged(state) }
        connection.connect(to: serverURL)
        dex.load()
    }

    func reconnect() {
        reconnectTask?.cancel()
        reconnectAttempts = 0
        connection.connect(to: serverURL)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        inForeground = phase == .active
        if phase == .active, connectionState == .disconnected {
            reconnect()
        }
    }

    private func connectionChanged(_ state: ShowdownConnection.State) {
        connectionState = state
        switch state {
        case .connected:
            reconnectAttempts = 0
        case .disconnected:
            challstr = nil
            isNamed = false
            searching = []
            scheduleReconnect()
        case .connecting:
            break
        }
    }

    private func scheduleReconnect() {
        guard inForeground else { return }
        reconnectTask?.cancel()
        let delay = min(30, pow(2, Double(reconnectAttempts)))
        reconnectAttempts += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.connectionState == .disconnected else { return }
            self.connection.connect(to: self.serverURL)
        }
    }

    // MARK: - Sending

    func send(_ text: String) {
        connection.send(text)
    }

    func sendGlobal(_ command: String) {
        send("|" + command)
    }

    // MARK: - Incoming

    private func handle(_ frame: ServerFrame) {
        if frame.roomID.hasPrefix("battle-") {
            handleBattleFrame(frame)
            return
        }
        for raw in frame.lines {
            let line = ProtocolLine(raw)
            switch line.kind {
            case "updateuser":
                applyUpdateUser(line)
            case "challstr":
                challstr = line[0]
                autoLogin()
            case "formats":
                formatSections = FormatParser.parse(line.args)
            case "updatesearch":
                applyUpdateSearch(line[0])
            case "updatechallenges":
                applyUpdateChallenges(line[0])
            case "popup":
                var text = line[0]
                if text.hasPrefix("|html|") { text = BattleText.stripHTML(String(text.dropFirst(6))) }
                alertMessage = text.replacingOccurrences(of: "||", with: "\n")
            case "nametaken":
                loginInProgress = false
                loginError = line[1].isEmpty ? "That name is taken." : line[1]
            case "pm":
                handlePM(line)
            default:
                break
            }
        }
    }

    private func applyUpdateUser(_ line: ProtocolLine) {
        var name = line[0]
        if let first = name.first, !(first.isLetter || first.isNumber) {
            name.removeFirst()
        }
        if name.hasSuffix("@!") { name = String(name.dropLast(2)) }
        username = name
        isNamed = line[1] == "1"
        avatar = line[2]
        if isNamed {
            loginInProgress = false
            loginError = nil
            if let action = pendingNamedAction {
                pendingNamedAction = nil
                action()
            }
        }
        for battle in battles { battle.myUserID = userID }
    }

    private struct SearchUpdate: Decodable {
        var searching: [String]?
        var games: [String: String]?
    }

    private func applyUpdateSearch(_ json: String) {
        guard let update = try? JSONDecoder().decode(SearchUpdate.self, from: Data(json.utf8)) else { return }
        searching = update.searching ?? []
        for roomID in (update.games ?? [:]).keys where roomID.hasPrefix("battle-") {
            knownGames.insert(roomID)
            if battle(roomID) == nil {
                // A battle we're in but not viewing (e.g. after reconnecting): join it.
                sendGlobal("/join \(roomID)")
            }
        }
    }

    private struct ChallengeUpdate: Decodable {
        struct Outgoing: Decodable {
            var to: String
            var format: String
        }
        var challengesFrom: [String: String]?
        var challengeTo: Outgoing?
    }

    private func applyUpdateChallenges(_ json: String) {
        guard let update = try? JSONDecoder().decode(ChallengeUpdate.self, from: Data(json.utf8)) else { return }
        incomingChallenges = (update.challengesFrom ?? [:]).map { Challenge(user: $0.key, format: $0.value) }.sorted { $0.user < $1.user }
        outgoingChallenge = update.challengeTo.map { Challenge(user: $0.to, format: $0.format) }
    }

    private func handlePM(_ line: ProtocolLine) {
        // Challenges also arrive as PMs; the updatechallenges message covers them.
        let message = line[2]
        if message.hasPrefix("/error ") {
            alertMessage = String(message.dropFirst(7))
        }
    }

    private func handleBattleFrame(_ frame: ServerFrame) {
        let roomID = frame.roomID
        let isInit = frame.lines.contains { $0.hasPrefix("|init|") }
        if frame.lines.contains(where: { $0.hasPrefix("|deinit") || $0.hasPrefix("|noinit") }) {
            if let index = battles.firstIndex(where: { $0.id == roomID }) {
                if presentedBattle?.id == roomID { presentedBattle = nil }
                battles.remove(at: index)
            }
            return
        }
        var controller = battle(roomID)
        if controller == nil {
            guard isInit || frame.lines.contains(where: { $0.hasPrefix("|request|") }) else { return }
            let created = BattleController(roomID: roomID, app: self)
            battles.append(created)
            controller = created
            let alreadyKnown = knownGames.contains(roomID)
            knownGames.insert(roomID)
            if presentedBattle == nil && !alreadyKnown {
                presentedBattle = created
            }
        }
        if isInit { controller?.reset() }
        controller?.receive(frame.lines, instant: isInit)
    }

    func battle(_ roomID: String) -> BattleController? {
        battles.first { $0.id == roomID }
    }

    func leave(_ battle: BattleController) {
        sendGlobal("/leave \(battle.id)")
        knownGames.remove(battle.id)
        if presentedBattle === battle { presentedBattle = nil }
        battles.removeAll { $0 === battle }
    }

    // MARK: - Account

    func login(name: String, password: String?) {
        loginError = nil
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let challstr else {
            loginError = "Not connected yet. Try again in a moment."
            return
        }
        loginInProgress = true
        Task {
            do {
                let assertion = try await LoginService.assertion(username: trimmed, password: password, challstr: challstr)
                if let password, !password.isEmpty {
                    Keychain.save(username: trimmed, password: password)
                    isRegisteredLogin = true
                } else {
                    Keychain.delete()
                    isRegisteredLogin = false
                }
                UserDefaults.standard.set(trimmed, forKey: "preferredName")
                sendGlobal("/trn \(trimmed),0,\(assertion)")
            } catch {
                pendingNamedAction = nil
                loginInProgress = false
                loginError = error.localizedDescription
            }
        }
    }

    func logout() {
        Keychain.delete()
        UserDefaults.standard.removeObject(forKey: "preferredName")
        isRegisteredLogin = false
        sendGlobal("/logout")
    }

    private func autoLogin() {
        guard !isNamed else { return }
        if let saved = Keychain.load() {
            login(name: saved.username, password: saved.password)
        } else if let name = UserDefaults.standard.string(forKey: "preferredName"), !name.isEmpty {
            login(name: name, password: nil)
        }
    }

    // MARK: - Matchmaking

    private func useTeam(_ team: Team?) {
        if let team, !team.pokemon.isEmpty {
            sendGlobal("/utm \(TeamText.pack(team.pokemon))")
        } else {
            sendGlobal("/utm null")
        }
    }

    func search(format: BattleFormat, team: Team?) {
        if format.requiresTeam && team == nil {
            alertMessage = "\(format.name) needs a team. Build or import one in the Teams tab."
            return
        }
        whenNamed { [weak self] in
            self?.useTeam(format.requiresTeam ? team : nil)
            self?.sendGlobal("/search \(format.id)")
        }
    }

    func cancelSearch() {
        sendGlobal("/cancelsearch")
    }

    func challenge(user: String, format: BattleFormat, team: Team?) {
        if format.requiresTeam && team == nil {
            alertMessage = "\(format.name) needs a team. Build or import one in the Teams tab."
            return
        }
        whenNamed { [weak self] in
            self?.useTeam(format.requiresTeam ? team : nil)
            self?.sendGlobal("/challenge \(user), \(format.id)")
        }
    }

    func accept(_ challenge: Challenge, team: Team?) {
        let needsTeam = format(id: challenge.format)?.requiresTeam ?? !challenge.format.contains("random")
        if needsTeam && team == nil {
            alertMessage = "This challenge needs a team for \(format(id: challenge.format)?.name ?? challenge.format)."
            return
        }
        useTeam(needsTeam ? team : nil)
        sendGlobal("/accept \(challenge.user)")
    }

    func reject(_ challenge: Challenge) {
        sendGlobal("/reject \(challenge.user)")
    }

    func cancelChallenge() {
        guard let outgoing = outgoingChallenge else { return }
        sendGlobal("/cancelchallenge \(outgoing.user)")
    }

    /// Showdown requires a chosen name to battle. If the player hasn't picked one,
    /// sign them in under a generated name and run the action once that lands.
    private func whenNamed(_ action: @escaping () -> Void) {
        if isNamed {
            action()
            return
        }
        guard challstr != nil else {
            alertMessage = "Still connecting to Showdown…"
            return
        }
        pendingNamedAction = action
        login(name: "Trainer\(Int.random(in: 10000...99999))", password: nil)
    }
}
