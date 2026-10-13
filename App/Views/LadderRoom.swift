import SwiftUI
import ShowdownKit

/// Ladder rankings (`panel-ladder.tsx`), from pokemonshowdown.com/ladder/<format>.json.
struct LadderRoom: View {
    @AppStorage("ladderFormat") private var formatID = "gen9ou"
    @Environment(AppModel.self) private var app
    @State private var entries: [Entry] = []
    @State private var loading = false
    @State private var failed = false

    struct Entry: Decodable, Identifiable {
        var userid: String
        var username: String
        var elo: Double
        var gxe: Double?
        var rpr: Double?
        var rprd: Double?
        var id: String { userid }
    }

    private struct Response: Decodable {
        var toplist: [Entry]
    }

    var body: some View {
        RoomPageStatic {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ladder").font(PS.font(20, bold: true)).foregroundStyle(Color(hex: 0x555555))
                FormatSelect(formatID: $formatID, mode: .ladder)
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if failed {
                    Text("Couldn't load the ladder.").font(PS.italic(13))
                }
            }
            .padding(10)
            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 4) {
                            Text("\(index + 1)").frame(width: 34, alignment: .trailing)
                            Text(entry.username).font(PS.font(13, bold: true)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(Int(entry.elo))").frame(width: 48, alignment: .trailing)
                            Text(entry.gxe.map { String(format: "%.1f", $0) } ?? "–").frame(width: 44, alignment: .trailing)
                            Text(glicko(entry)).frame(width: 74, alignment: .trailing)
                        }
                        .font(PS.font(12))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(index % 2 == 0 ? Color.white.opacity(0.5) : Color.clear)
                    }
                }
            }
        }
        .task(id: formatID) { await load() }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("").frame(width: 34)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Elo").frame(width: 48, alignment: .trailing)
            Text("GXE").frame(width: 44, alignment: .trailing)
            Text("Glicko-1").frame(width: 74, alignment: .trailing)
        }
        .font(PS.font(11, bold: true))
        .foregroundStyle(Color(hex: 0x555555))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: 0xDCE2E7))
    }

    private func glicko(_ entry: Entry) -> String {
        guard let rpr = entry.rpr, let rprd = entry.rprd else { return "–" }
        return "\(Int(rpr)) ± \(Int(rprd))"
    }

    private func load() async {
        loading = true
        failed = false
        defer { loading = false }
        guard let url = URL(string: "https://pokemonshowdown.com/ladder/\(formatID).json"),
              let result = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(Response.self, from: result.0) else {
            failed = true
            entries = []
            return
        }
        entries = response.toplist
    }
}

/// Non-scrolling pale room background.
struct RoomPageStatic<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PS.roomLight)
    }
}
