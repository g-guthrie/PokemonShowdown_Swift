import SwiftUI
import ShowdownKit

/// Renders `app.popup` and `app.alertMessage` as Showdown popups over a dimmed overlay.
struct PopupHost: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            if let popup = app.popup {
                overlay { app.popup = nil }
                content(for: popup)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 50)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .id(popup.id)
            } else if let message = app.alertMessage {
                overlay { app.alertMessage = nil }
                PSPopupBox(maxWidth: 320) {
                    Text(message)
                        .font(PS.font(14))
                        .padding(.vertical, 6)
                    HStack {
                        Spacer()
                        Button {
                            app.alertMessage = nil
                        } label: {
                            Text("OK").font(PS.font(13, bold: true))
                        }
                        .buttonStyle(PSButtonStyle())
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }
                .padding(24)
            }
        }
        .animation(.easeOut(duration: 0.15), value: app.popup?.id)
        .animation(.easeOut(duration: 0.15), value: app.alertMessage)
    }

    private func overlay(_ dismiss: @escaping () -> Void) -> some View {
        Color(red: 212 / 255, green: 212 / 255, blue: 212 / 255, opacity: 0.5)
            .ignoresSafeArea()
            .onTapGesture(perform: dismiss)
    }

    @ViewBuilder
    private func content(for popup: Popup) -> some View {
        switch popup {
        case let .format(selected, mode, onSelect):
            FormatSheet(selected: selected, mode: mode, onSelect: onSelect)
        case let .team(format, selected, onSelect):
            TeamSheet(formatID: format, selected: selected, onSelect: onSelect)
        case .login:
            LoginPopup()
        case .options:
            OptionsPopup()
        case .findUser:
            FindUserPopup()
        case .watchBattles:
            WatchBattlesPopup()
        case let .acceptChallenge(challenge):
            PSPopupBox {
                Text("Challenge from \(challenge.user)").font(PS.font(15, bold: true))
                Button("Go to main menu") { app.popup = nil; app.currentRoom = .home }
                    .buttonStyle(PSButtonStyle())
            }
        case let .confirm(message, button, perform):
            PSPopupBox(maxWidth: 320) {
                Text(message).font(PS.font(14)).padding(.vertical, 6)
                HStack(spacing: 8) {
                    Spacer()
                    Button {
                        app.popup = nil
                        perform()
                    } label: {
                        Text(button).font(PS.font(13, bold: true))
                    }
                    .buttonStyle(PSButtonStyle())
                    Button("Cancel") { app.popup = nil }
                        .buttonStyle(PSButtonStyle())
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }
}

/// A plain list row inside popups (`.popupmenu button.option`).
struct PopupOption<Label: View>: View {
    var selected = false
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(PS.font(13))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Color.white.opacity(0.6) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? Color(hex: 0x555555) : .clear, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(OptionPressStyle())
    }

    private struct OptionPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(RoundedRectangle(cornerRadius: 4).fill(configuration.isPressed ? Color(hex: 0xF8F8F8) : .clear))
        }
    }
}

// MARK: - Native picker sheets

/// Format picker: a native sheet with search and sections, in Showdown's type.
struct FormatSheet: View {
    var selected: String
    var mode: FormatMode
    var onSelect: (String) -> Void
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
            ScrollViewReader { reader in
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.formats) { format in
                                Button {
                                    onSelect(format.id)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        FAIcon(format.isRandom ? .random : .trophy, size: 13)
                                            .foregroundStyle(Color(hex: 0x6688AA))
                                            .frame(width: 18)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(format.shortName)
                                                .font(PS.font(15))
                                                .foregroundStyle(.black)
                                            if let gen = format.genLabel, gen != "Gen 9" {
                                                Text(gen).font(PS.font(11)).foregroundStyle(PS.gray)
                                            }
                                        }
                                        Spacer()
                                        if format.id == selected {
                                            FAIcon(.check, size: 15).foregroundStyle(Color(hex: 0x2277FF))
                                        }
                                    }
                                    .frame(minHeight: 34)
                                    .contentShape(Rectangle())
                                }
                                .id(format.id)
                                .listRowBackground(format.id == selected ? Color(hex: 0xE3ECF5) : Color.white)
                            }
                        } header: {
                            Text(section.name)
                                .font(PS.font(12, bold: true))
                                .foregroundStyle(Color(hex: 0x557799))
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(PS.roomOpaque)
                .onAppear { reader.scrollTo(selected, anchor: .center) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search formats")
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if app.formatSections.isEmpty {
                    ProgressView("Loading formats…")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Team picker sheet.
struct TeamSheet: View {
    var formatID: String
    var selected: String
    var onSelect: (String) -> Void
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let matching = teams.teams.filter { $0.format == formatID }
                let others = teams.teams.filter { $0.format != formatID }
                if !matching.isEmpty {
                    Section {
                        ForEach(matching) { row($0) }
                    } header: {
                        header("\(app.format(id: formatID).map(FormatSelect.displayName) ?? formatID) teams")
                    }
                }
                if !others.isEmpty {
                    Section {
                        ForEach(others) { row($0) }
                    } header: {
                        header("Other teams")
                    }
                }
                Section {
                    Button {
                        dismiss()
                        app.open(.teambuilder)
                    } label: {
                        HStack(spacing: 8) {
                            FAIcon(.pencilSquare, size: 15)
                            Text(teams.teams.isEmpty ? "You have no teams. Open Teambuilder" : "Open Teambuilder")
                                .font(PS.font(14))
                        }
                        .foregroundStyle(Color(hex: 0x2277FF))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(PS.roomOpaque)
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(PS.font(12, bold: true))
            .foregroundStyle(Color(hex: 0x557799))
            .textCase(nil)
    }

    private func row(_ team: Team) -> some View {
        Button {
            onSelect(team.id.uuidString)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(team.name).font(PS.font(14, bold: true)).foregroundStyle(.black)
                    HStack(spacing: -6) {
                        ForEach(team.pokemon.prefix(6)) { set in
                            PokemonIcon(species: set.species, female: set.gender == "F")
                        }
                    }
                }
                Spacer()
                if team.id.uuidString == selected {
                    FAIcon(.check, size: 15).foregroundStyle(Color(hex: 0x2277FF))
                }
            }
            .contentShape(Rectangle())
        }
        .listRowBackground(team.id.uuidString == selected ? Color(hex: 0xE3ECF5) : Color.white)
    }
}

// MARK: - Login

private struct LoginPopup: View {
    @Environment(AppModel.self) private var app
    @State private var name = ""
    @State private var password = ""
    @State private var needsPassword = false
    @State private var changingName = false
    @FocusState private var focused: Bool

    var body: some View {
        PSPopupBox(maxWidth: 320) {
            if app.isNamed && !needsPassword && !changingName {
                HStack(spacing: 10) {
                    TrainerSprite(avatar: app.avatar, size: 80)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.username).font(PS.font(16, bold: true))
                        Text(app.isRegisteredLogin ? "Registered" : "Unregistered").font(PS.font(12)).foregroundStyle(PS.gray)
                    }
                }
                .padding(.top, 6)
                HStack(spacing: 8) {
                    Button("Change name") { changingName = true; focused = true }
                        .buttonStyle(PSButtonStyle())
                    Button {
                        app.logout()
                        app.popup = nil
                    } label: {
                        HStack(spacing: 4) { FAIcon(.signOut, size: 13); Text("Log out") }
                    }
                    .buttonStyle(PSButtonStyle())
                }
                .padding(.bottom, 6)
            } else {
                Text(needsPassword ? "The name \(name.trimmingCharacters(in: .whitespaces)) is registered" : "Choose your name:")
                    .font(PS.font(15, bold: true))
                    .padding(.top, 6)
                if needsPassword {
                    Text("Password:").font(PS.font(12, bold: true))
                    SecureField("", text: $password)
                        .textFieldStyle(PSTextFieldStyle())
                        .focused($focused)
                        .onSubmit(submit)
                } else {
                    TextField("", text: $name)
                        .textFieldStyle(PSTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .onSubmit(submit)
                }
                if let error = app.loginError, error != LoginError.needsPassword.errorDescription {
                    Text(error).font(PS.font(12, bold: true)).foregroundStyle(Color(hex: 0xEE4422))
                }
                HStack(spacing: 8) {
                    Button(action: submit) {
                        HStack(spacing: 6) {
                            if app.loginInProgress { ProgressView().controlSize(.mini) }
                            Text(needsPassword ? "Log in" : "Choose name").font(PS.font(13, bold: true))
                        }
                    }
                    .buttonStyle(PSButtonStyle())
                    Button("Cancel") { app.popup = nil }
                        .buttonStyle(PSButtonStyle())
                }
                .padding(.bottom, 6)
            }
        }
        .onAppear { focused = !app.isNamed }
        .onChange(of: app.loginError) { _, error in
            if error == LoginError.needsPassword.errorDescription {
                needsPassword = true
                focused = true
            }
        }
        .onChange(of: app.isNamed) { _, named in
            if named && !name.isEmpty && toID(app.username) == toID(name) { app.popup = nil }
        }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        app.login(name: trimmed, password: password.isEmpty ? nil : password)
    }
}

// MARK: - Options

private struct OptionsPopup: View {
    @Environment(AppModel.self) private var app
    @Environment(DexStore.self) private var dex
    @AppStorage("background") private var backgroundID = "charizards"
    @AppStorage("animationSpeed") private var animationSpeed = 1.0
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        PSPopupBox {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    PopupHeader(text: "Graphics")
                    Text("Background:").font(PS.font(12, bold: true))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                        ForEach(PSBackground.all) { bg in
                            Button {
                                backgroundID = bg.id
                            } label: {
                                VStack(spacing: 2) {
                                    RemoteImage(path: "fx/client-bg-\(bg.id).jpg", pixelated: false)
                                        .scaledToFill()
                                        .frame(width: 92, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(bg.id == backgroundID ? Color(hex: 0x004488) : PS.border, lineWidth: bg.id == backgroundID ? 2 : 1))
                                    Text(bg.name).font(PS.font(11))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    PopupHeader(text: "Battles")
                    HStack {
                        Text("Animation speed:").font(PS.font(12))
                        Spacer()
                        Menu {
                            ForEach([0.5, 1, 1.5, 2, 3], id: \.self) { speed in
                                Button(speedLabel(speed)) { animationSpeed = speed }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(speedLabel(animationSpeed))
                                FAIcon(.caretDown, size: 13)
                            }
                            .font(PS.font(12))
                            .foregroundStyle(.black)
                        }
                        .buttonStyle(PSButtonStyle(size: .small))
                    }
                    PSCheckbox(title: "Vibrate on hits", isOn: $haptics)
                    PopupHeader(text: "Data")
                    HStack(spacing: 8) {
                        Button {
                            dex.load(forceRefresh: true)
                        } label: {
                            HStack(spacing: 4) { FAIcon(.refresh, size: 12); Text("Refresh Pokédex") }
                        }
                        .buttonStyle(PSButtonStyle(size: .small))
                        Button {
                            app.reconnect()
                            app.popup = nil
                        } label: {
                            Text("Reconnect")
                        }
                        .buttonStyle(PSButtonStyle(size: .small))
                    }
                    Text("Unofficial iOS client for Pokémon Showdown. Data and sprites from play.pokemonshowdown.com.")
                        .font(PS.font(10))
                        .foregroundStyle(PS.gray)
                        .padding(.top, 6)
                        .padding(.bottom, 6)
                }
            }
            .frame(maxHeight: 560)
        }
    }

    private func speedLabel(_ speed: Double) -> String {
        switch speed {
        case ..<0.75: return "Slow"
        case ..<1.25: return "Normal"
        case ..<1.75: return "Fast"
        case ..<2.5: return "Faster"
        default: return "Hyperfast"
        }
    }
}

// MARK: - Find a user / challenge

private struct FindUserPopup: View {
    @Environment(AppModel.self) private var app
    @Environment(TeamStore.self) private var teams
    @AppStorage("selectedFormat") private var defaultFormat = "gen9randombattle"
    @State private var user = ""
    @State private var formatID = ""
    @State private var teamID = ""

    private var format: BattleFormat? { app.format(id: formatID) }

    var body: some View {
        PSPopupBox(maxWidth: 320) {
            Text("Challenge a user").font(PS.font(15, bold: true)).padding(.top, 6)
            Text("Username:").font(PS.font(12, bold: true))
            TextField("", text: $user)
                .textFieldStyle(PSTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Text("Format:").font(PS.font(12, bold: true))
            FormatSelect(formatID: $formatID, mode: .challenge)
            if format?.requiresTeam ?? false {
                Text("Team:").font(PS.font(12, bold: true))
                TeamSelect(formatID: formatID, teamID: $teamID)
            }
            HStack(spacing: 8) {
                Button {
                    guard let format else { return }
                    app.popup = nil
                    app.challenge(user: user.trimmingCharacters(in: .whitespaces), format: format, team: teams.team(id: UUID(uuidString: teamID)))
                } label: {
                    Text("Challenge").font(PS.font(13, bold: true))
                }
                .buttonStyle(PSButtonStyle())
                .disabled(user.trimmingCharacters(in: .whitespaces).isEmpty || format == nil)
                Button("Cancel") { app.popup = nil }
                    .buttonStyle(PSButtonStyle())
            }
            .padding(.vertical, 6)
        }
        .onAppear { if formatID.isEmpty { formatID = defaultFormat } }
    }
}

// MARK: - Watch a battle

private struct WatchBattlesPopup: View {
    @Environment(AppModel.self) private var app
    @State private var formatID = ""

    var body: some View {
        PSPopupBox {
            HStack {
                Text("Watch a battle").font(PS.font(15, bold: true))
                Spacer()
                Button {
                    app.requestRoomList(format: formatID)
                } label: {
                    HStack(spacing: 4) { FAIcon(.refresh, size: 12); Text("Refresh") }
                }
                .buttonStyle(PSButtonStyle(size: .small))
            }
            .padding(.top, 6)
            PSSelect(action: {
                app.sheet = .format(selected: formatID, mode: .ladder) { picked in
                    formatID = picked
                    app.requestRoomList(format: picked)
                }
            }) {
                Text(app.format(id: formatID)?.name ?? "(All formats)").lineLimit(1)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if app.roomList.isEmpty {
                        Text("No battles are going on").font(PS.italic(13)).padding(.vertical, 10)
                    }
                    ForEach(app.roomList, id: \.id) { room in
                        PopupOption {
                            app.popup = nil
                            app.watch(room.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(room.p1) vs. \(room.p2)").font(PS.font(13, bold: true)).lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(app.format(id: String(room.id.split(separator: "-").dropFirst().first ?? ""))?.name ?? room.id)
                                    if let elo = room.minElo { Text("rated \(elo)") }
                                }
                                .font(PS.font(11))
                                .foregroundStyle(PS.gray)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 460)
        }
        .onAppear { app.requestRoomList(format: formatID) }
    }
}
