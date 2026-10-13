import Foundation
import Observation
import ShowdownKit
import SwiftUI

/// Showdown's Pokédex, moves, items and abilities, cached on disk and refreshed every few days.
@Observable
@MainActor
final class DexStore {
    var data = DexData()
    var isLoaded = false

    private static let baseURL = "https://play.pokemonshowdown.com/data/"
    private static let files = ["pokedex.json", "moves.json", "items.js", "abilities.js"]
    private static let maxAge: TimeInterval = 3 * 24 * 3600

    private var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("dex", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func load(forceRefresh: Bool = false) {
        let dir = cacheDirectory
        Task {
            if !forceRefresh, let cached = await Self.parse(directory: dir) {
                data = cached
                isLoaded = true
            }
            let stale = forceRefresh || Self.isStale(directory: dir)
            guard stale || !isLoaded else { return }
            await Self.download(to: dir)
            if let fresh = await Self.parse(directory: dir) {
                data = fresh
                isLoaded = true
            }
        }
    }

    private nonisolated static func isStale(directory: URL) -> Bool {
        let url = directory.appendingPathComponent("pokedex.json")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else { return true }
        return Date().timeIntervalSince(modified) > maxAge
    }

    private nonisolated static func download(to directory: URL) async {
        await withTaskGroup(of: Void.self) { group in
            for file in files {
                group.addTask {
                    guard let url = URL(string: baseURL + file),
                          let result = try? await URLSession.shared.data(from: url),
                          (result.1 as? HTTPURLResponse)?.statusCode == 200, !result.0.isEmpty else { return }
                    try? result.0.write(to: directory.appendingPathComponent(file), options: .atomic)
                }
            }
        }
    }

    private nonisolated static func parse(directory: URL) async -> DexData? {
        await Task.detached(priority: .userInitiated) {
            guard let pokedex = try? Data(contentsOf: directory.appendingPathComponent("pokedex.json")),
                  let species = try? DexData.decodeSpecies(pokedex) else { return nil }
            var result = DexData(species: species)
            if let moves = try? Data(contentsOf: directory.appendingPathComponent("moves.json")) {
                result.moves = (try? DexData.decodeMoves(moves)) ?? [:]
            }
            if let items = try? String(contentsOf: directory.appendingPathComponent("items.js"), encoding: .utf8) {
                result.items = DexData.parseNameTable(items)
                result.itemSprites = DexData.parseItemSprites(items)
            }
            if let abilities = try? String(contentsOf: directory.appendingPathComponent("abilities.js"), encoding: .utf8) {
                result.abilities = DexData.parseNameTable(abilities)
            }
            return result
        }.value
    }
}

/// The player's teams, saved as JSON in Documents.
@Observable
@MainActor
final class TeamStore {
    var teams: [Team] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("teams.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Team].self, from: data) {
            teams = decoded
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(teams) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func team(id: UUID?) -> Team? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    func update(_ team: Team) {
        var updated = team
        updated.updated = Date()
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = updated
        } else {
            teams.insert(updated, at: 0)
        }
        save()
    }

    @discardableResult
    func create(format: String) -> Team {
        let team = Team(name: "Untitled Team", format: format, pokemon: [])
        teams.insert(team, at: 0)
        save()
        return team
    }

    @discardableResult
    func importText(_ text: String, format: String) -> [Team] {
        let imported = TeamText.importTeams(text, defaultFormat: format).filter { !$0.pokemon.isEmpty }
        teams.insert(contentsOf: imported, at: 0)
        save()
        return imported
    }

    func duplicate(_ team: Team) {
        var copy = team
        copy.id = UUID()
        copy.name = team.name + " (copy)"
        copy.pokemon = team.pokemon.map { set in
            var new = set
            new.id = UUID()
            return new
        }
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams.insert(copy, at: index + 1)
        } else {
            teams.insert(copy, at: 0)
        }
        save()
    }

    func delete(_ team: Team) {
        teams.removeAll { $0.id == team.id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        teams.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
