import SwiftUI
import ShowdownKit

/// The Teambuilder tab: team list → team → set, each a pushed page like Showdown's panels.
struct TeambuilderRoom: View {
    @State private var path: [TeambuilderPage] = []

    var body: some View {
        NavigationStack(path: $path) {
            TeamListPage(path: $path)
                .navigationDestination(for: TeambuilderPage.self) { page in
                    switch page {
                    case .team(let id):
                        TeamPage(teamID: id, path: $path)
                    case .set(let teamID, let setID):
                        SetPage(teamID: teamID, setID: setID)
                    case .importText:
                        ImportPage(path: $path)
                    }
                }
        }
    }
}

enum TeambuilderPage: Hashable {
    case team(UUID)
    case set(team: UUID, set: UUID)
    case importText
}

/// Pale room background used by every teambuilder page.
struct RoomPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PS.roomLight)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// `← List`-style back button.
struct BackButton: View {
    var title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                FAIcon(.chevronLeft, size: 11)
                Text(title)
            }
        }
        .buttonStyle(PSButtonStyle(size: .small))
    }
}

// MARK: - Team list

private struct TeamListPage: View {
    @Binding var path: [TeambuilderPage]
    @Environment(TeamStore.self) private var teams
    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var filterFormat = ""

    private var shown: [Team] {
        teams.teams.filter { team in
            (filterFormat.isEmpty || team.format == filterFormat)
                && (query.isEmpty || team.name.localizedCaseInsensitiveContains(query)
                    || team.pokemon.contains { $0.species.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        RoomPage {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(filterFormat.isEmpty ? "All teams" : (app.format(id: filterFormat)?.name ?? filterFormat))
                    .font(PS.font(20, bold: true))
                Text("(\(shown.count))").font(PS.font(16))
            }
            .foregroundStyle(Color(hex: 0x555555))
            HStack(spacing: 6) {
                Button {
                    let format = filterFormat.isEmpty ? (UserDefaults.standard.string(forKey: "lastTeamFormat") ?? "gen9ou") : filterFormat
                    let team = teams.create(format: format)
                    path.append(.team(team.id))
                } label: {
                    HStack(spacing: 5) { FAIcon(.plusCircle, size: 16); Text("New Team") }
                }
                .buttonStyle(PSButtonStyle(size: .big))
                Button {
                    path.append(.importText)
                } label: {
                    HStack(spacing: 5) { FAIcon(.upload, size: 14); Text("Import") }
                }
                .buttonStyle(PSButtonStyle(size: .big))
            }
            HStack(spacing: 6) {
                TextField("search teams", text: $query)
                    .textFieldStyle(PSTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                PSSelect(action: {
                    app.sheet = .format(selected: filterFormat, mode: .teambuilder) { filterFormat = $0 }
                }) {
                    Text(filterFormat.isEmpty ? "(all)" : (app.format(id: filterFormat).map(FormatSelect.displayName) ?? filterFormat))
                        .lineLimit(1)
                }
                .frame(width: 150)
                if !filterFormat.isEmpty {
                    Button {
                        filterFormat = ""
                    } label: {
                        FAIcon(.times, size: 13)
                    }
                    .buttonStyle(PSButtonStyle(size: .small))
                }
            }
            if teams.teams.isEmpty {
                Text("you don't have any teams lol")
                    .font(PS.italic(15))
                    .foregroundStyle(Color(hex: 0x555555))
                    .padding(.vertical, 20)
            }
            ForEach(shown) { team in
                TeamRow(team: team) {
                    path.append(.team(team.id))
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = TeamText.export(team.pokemon)
                    } label: {
                        Label("Copy as text", systemImage: "doc.on.doc")
                    }
                    Button {
                        teams.duplicate(team)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        teams.delete(team)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            if !teams.teams.isEmpty {
                Button {
                    UIPasteboard.general.string = TeamText.exportBackup(teams.teams)
                    app.alertMessage = "All teams copied to the clipboard."
                } label: {
                    HStack(spacing: 4) { FAIcon(.download, size: 12); Text("Backup all teams") }
                }
                .buttonStyle(PSButtonStyle(size: .small))
                .padding(.top, 10)
            }
        }
    }
}

/// `.team` button: name, format, and party icons.
private struct TeamRow: View {
    var team: Team
    var action: () -> Void
    @Environment(AppModel.self) private var app

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("[\(team.format)]").font(PS.font(11)).foregroundStyle(PS.gray)
                    Text(team.name).font(PS.font(13, bold: true)).foregroundStyle(.black).lineLimit(1)
                }
                HStack(spacing: -4) {
                    ForEach(team.pokemon.prefix(6)) { set in
                        PokemonIcon(species: set.species, female: set.gender == "F")
                    }
                    if team.pokemon.isEmpty {
                        Text("(empty team)").font(PS.italic(12)).foregroundStyle(PS.gray).frame(height: 30)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TeamButtonStyle())
    }
}

struct TeamButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4).fill(
                    configuration.isPressed
                        ? LinearGradient(colors: [Color(hex: 0xD1DCE6), Color(hex: 0xE7EDF2)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(hex: 0xF6F6F6), Color(hex: 0xE3E3E3)], startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: 0x888888), lineWidth: 1))
            .contentShape(Rectangle())
    }
}

// MARK: - Import

private struct ImportPage: View {
    @Binding var path: [TeambuilderPage]
    @Environment(TeamStore.self) private var teams
    @Environment(AppModel.self) private var app
    @State private var text = ""
    @State private var formatID = UserDefaults.standard.string(forKey: "lastTeamFormat") ?? "gen9ou"

    var body: some View {
        RoomPage {
            HStack {
                BackButton(title: "List")
                Spacer()
            }
            Text("Import from text").font(PS.font(16, bold: true))
            Text("Paste a team exported from Showdown or a Pokepaste. A backup with several teams works too.")
                .font(PS.font(12))
                .foregroundStyle(PS.subtleText)
            HStack(spacing: 6) {
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { text = first }
                }
                .buttonBorderShape(.roundedRectangle(radius: 5))
                .tint(Color(hex: 0x6688AA))
                .labelStyle(.titleAndIcon)
                Spacer()
                Text("Format:").font(PS.font(12, bold: true))
                FormatSelect(formatID: $formatID, mode: .teambuilder)
                    .frame(width: 150)
            }
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 320)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF8FBFD)))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(PS.border, lineWidth: 1))
            Button {
                let imported = teams.importText(text, format: formatID)
                if imported.isEmpty {
                    app.alertMessage = "No Pokémon found in that text."
                    return
                }
                path.removeLast()
                if imported.count == 1, let team = imported.first {
                    path.append(.team(team.id))
                }
            } label: {
                Text("Import").font(PS.font(13, bold: true))
            }
            .buttonStyle(PSButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
