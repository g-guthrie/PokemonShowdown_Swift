import XCTest
@testable import ShowdownKit

/// Replays every log in $SHOWDOWN_LOG_DIR (generated with the official simulator) and checks invariants.
final class StressTests: XCTestCase {
    func testReplayDirectory() throws {
        guard let dir = ProcessInfo.processInfo.environment["SHOWDOWN_LOG_DIR"] else { throw XCTSkip("SHOWDOWN_LOG_DIR not set") }
        let files = try FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".log") }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            var state = BattleState(roomID: file)
            let text = try String(contentsOfFile: dir + "/" + file, encoding: .utf8)
            for raw in text.components(separatedBy: "\n") {
                if raw.hasPrefix("|request|") {
                    XCTAssertNotNil(BattleRequest.parse(String(raw.dropFirst(9))), "\(file): bad request")
                    continue
                }
                state.apply(raw)
            }
            XCTAssertTrue(state.ended, file)
            for side in state.sides.values {
                XCTAssertLessThanOrEqual(side.pokemon.count, side.teamSize, "\(file) \(side.id): \(side.pokemon.map(\.name))")
            }
            let loser = state.sides.values.first { $0.name != state.winner }
            if let loser, state.winner != nil {
                XCTAssertEqual(loser.faintedCount, loser.teamSize, "\(file): loser fainted count")
            }
        }
    }
}
