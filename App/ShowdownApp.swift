import SwiftUI

@main
struct ShowdownApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(app.dex)
                .environment(app.teams)
                .preferredColorScheme(.dark)
                .fontDesign(.rounded)
                .task { app.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = ProcessInfo.processInfo.arguments.contains("-demoTeams") ? 1 : 0

    var body: some View {
        @Bindable var app = app
        TabView(selection: $tab) {
            PlayView()
                .tabItem { Label("Battle", systemImage: "bolt.fill") }
                .tag(0)
            TeamsView()
                .tabItem { Label("Teams", systemImage: "square.stack.3d.up.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .tint(Theme.accentPink)
        .fullScreenCover(item: $app.presentedBattle) { battle in
            BattleView(battle: battle)
        }
        .alert(
            "Showdown",
            isPresented: Binding(get: { app.alertMessage != nil }, set: { if !$0 { app.alertMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.alertMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            app.scenePhaseChanged(phase)
        }
    }
}
