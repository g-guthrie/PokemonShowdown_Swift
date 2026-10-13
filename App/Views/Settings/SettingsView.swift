import SwiftUI
import ShowdownKit

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(DexStore.self) private var dex
    @Environment(TeamStore.self) private var teams
    @AppStorage("animationSpeed") private var animationSpeed = 1.0
    @AppStorage("haptics") private var haptics = true
    @AppStorage("serverURL") private var serverURL = ""
    @State private var showLogin = false
    @State private var showBackupImport = false
    @State private var copiedBackup = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showLogin = true
                    } label: {
                        HStack(spacing: 14) {
                            TrainerAvatar(avatar: app.avatar, name: app.username.isEmpty ? "?" : app.username, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.username.isEmpty ? "Not connected" : app.username)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(app.isRegisteredLogin ? "Signed in" : app.isNamed ? "Unregistered name · tap to change" : "Guest · tap to choose a name")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                Section("Battle") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Animation speed")
                            Spacer()
                            Text(String(format: "%.1f×", animationSpeed))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Slider(value: $animationSpeed, in: 0.5...4, step: 0.5)
                            .tint(Theme.accentPink)
                    }
                    Toggle("Haptics", isOn: $haptics)
                        .tint(Theme.accentPink)
                }

                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Circle()
                            .fill(app.connectionState == .connected ? Color.green : app.connectionState == .connecting ? Color.yellow : Color.red)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    TextField(AppModel.defaultServer, text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())
                    Button("Reconnect") { app.reconnect() }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Leave blank for the main Pokémon Showdown server.")
                }

                Section("Data") {
                    Button {
                        dex.load(forceRefresh: true)
                    } label: {
                        HStack {
                            Text("Refresh Pokédex data")
                            Spacer()
                            Text(dex.isLoaded ? "\(dex.data.species.count) Pokémon" : "Loading…")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Button("Copy all teams (backup)") {
                        UIPasteboard.general.string = TeamText.exportBackup(teams.teams)
                        copiedBackup = true
                    }
                    .disabled(teams.teams.isEmpty)
                    Button("Import backup") { showBackupImport = true }
                }

                Section {
                    Text("An unofficial client for Pokémon Showdown. Battles, data and sprites come from play.pokemonshowdown.com. Pokémon is © Nintendo, Game Freak and The Pokémon Company.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                } header: {
                    Text("About")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AuroraBackground(intensity: 0.25))
            .navigationTitle("Settings")
            .sheet(isPresented: $showLogin) { LoginSheet() }
            .sheet(isPresented: $showBackupImport) { ImportTeamSheet { _ in } }
            .alert("Copied all teams", isPresented: $copiedBackup) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var statusText: String {
        switch app.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting…"
        case .disconnected: return "Disconnected"
        }
    }
}
