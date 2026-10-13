import SwiftUI
import ShowdownKit

struct FormatPickerSheet: View {
    enum Mode { case ladder, challenge, teambuilder }

    @Binding var selection: String
    var mode: Mode
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [FormatSection] {
        app.formatSections.compactMap { section in
            var filtered = section
            filtered.formats = section.formats.filter { format in
                let visible: Bool
                switch mode {
                case .ladder: visible = format.searchShow
                case .challenge: visible = format.challengeShow
                case .teambuilder: visible = format.requiresTeam
                }
                return visible && (query.isEmpty || format.name.localizedCaseInsensitiveContains(query))
            }
            return filtered.formats.isEmpty ? nil : filtered
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.name) {
                        ForEach(section.formats) { format in
                            Button {
                                selection = format.id
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: format.isRandom ? "shuffle" : format.isDoubles ? "person.2.fill" : "trophy.fill")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(Theme.accentGradient)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(format.shortName)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.white)
                                        if let gen = format.genLabel {
                                            Text(gen)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    if format.id == selection {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.accentPink)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $query, prompt: "Search formats")
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if app.formatSections.isEmpty {
                    ProgressView("Loading formats…")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
    }
}

struct LoginSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var needsPassword = false
    @FocusState private var focused: Field?

    enum Field { case name, password }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: 0.35)
                ScrollView {
                    VStack(spacing: 22) {
                        TrainerAvatar(avatar: app.avatar, name: app.username.isEmpty ? "?" : app.username, size: 92)
                            .shadow(color: Theme.accent.opacity(0.6), radius: 24)
                            .padding(.top, 24)
                        VStack(spacing: 4) {
                            Text(app.username.isEmpty ? "Not connected" : app.username)
                                .font(.title.weight(.heavy))
                            Text(app.isRegisteredLogin ? "Signed in" : app.isNamed ? "Unregistered name" : "Guest")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        VStack(spacing: 12) {
                            TextField("Username", text: $name)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focused, equals: .name)
                                .submitLabel(.go)
                                .onSubmit(submit)
                                .padding(14)
                                .glassCard(cornerRadius: 16)
                            SecureField(needsPassword ? "Password (required)" : "Password (registered names only)", text: $password)
                                .focused($focused, equals: .password)
                                .submitLabel(.go)
                                .onSubmit(submit)
                                .padding(14)
                                .glassCard(cornerRadius: 16, tint: needsPassword ? Theme.gold : nil)
                            if let error = app.loginError {
                                Text(error)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Color(hex: 0xFF8A8A))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
                        }

                        Button(action: submit) {
                            HStack {
                                if app.loginInProgress { ProgressView().tint(.white) }
                                Text(password.isEmpty ? "Choose name" : "Sign in")
                            }
                        }
                        .buttonStyle(GlowButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || app.loginInProgress)

                        if app.isRegisteredLogin || app.isNamed {
                            Button("Log out", role: .destructive) {
                                app.logout()
                            }
                            .buttonStyle(PillButtonStyle(tint: Color(hex: 0xFF6B6B)))
                        }

                        Text("Registered accounts sign in through Pokémon Showdown's login server. Your password is stored only in this device's Keychain.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal, 22)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if app.isNamed { name = app.username }
        }
        .onChange(of: app.loginError) { _, error in
            if error == LoginError.needsPassword.errorDescription {
                needsPassword = true
                focused = .password
            }
        }
        .onChange(of: app.isNamed) { _, named in
            if named && toID(app.username) == toID(name) { dismiss() }
        }
        .presentationBackground(Theme.background)
    }

    private func submit() {
        app.login(name: name, password: password.isEmpty ? nil : password)
    }
}

struct ChallengeSheet: View {
    var initialFormat: String
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @Environment(\.dismiss) private var dismiss
    @State private var user = ""
    @State private var formatID = ""
    @State private var teamID = ""
    @State private var showFormats = false

    private var format: BattleFormat? { app.format(id: formatID) }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(intensity: 0.3)
                VStack(spacing: 16) {
                    TextField("Opponent's username", text: $user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .glassCard(cornerRadius: 16)
                    Button {
                        showFormats = true
                    } label: {
                        HStack {
                            Text("Format").foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(format?.name ?? "Choose").foregroundStyle(.white).fontWeight(.semibold)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 16)
                    }
                    .buttonStyle(PressableStyle())
                    if format?.requiresTeam == true {
                        TeamMenu(formatID: formatID, selectedTeamID: $teamID)
                            .padding(14)
                            .glassCard(cornerRadius: 16)
                    }
                    Spacer()
                    Button {
                        guard let format else { return }
                        app.challenge(user: user, format: format, team: teams.team(id: UUID(uuidString: teamID)))
                        dismiss()
                    } label: {
                        Label("Send challenge", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(user.trimmingCharacters(in: .whitespaces).isEmpty || format == nil)
                }
                .padding(20)
            }
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showFormats) {
                FormatPickerSheet(selection: $formatID, mode: .challenge)
            }
        }
        .onAppear { if formatID.isEmpty { formatID = initialFormat } }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }
}

struct AcceptChallengeSheet: View {
    var challenge: Challenge
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @Environment(\.dismiss) private var dismiss
    @State private var teamID = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("\(challenge.user) wants to battle in \(app.format(id: challenge.format)?.name ?? challenge.format)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                TeamMenu(formatID: challenge.format, selectedTeamID: $teamID)
                    .padding(14)
                    .glassCard(cornerRadius: 16)
                Spacer()
                Button("Accept") {
                    app.accept(challenge, team: teams.team(id: UUID(uuidString: teamID)))
                    dismiss()
                }
                .buttonStyle(GlowButtonStyle())
                .disabled(teams.team(id: UUID(uuidString: teamID)) == nil)
            }
            .padding(20)
            .navigationTitle("Accept challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.background)
    }
}
