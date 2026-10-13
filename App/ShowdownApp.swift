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

    var body: some View {
        @Bindable var app = app
        TabView {
            PlayView()
                .tabItem { Label("Battle", systemImage: "bolt.fill") }
            TeamsView()
                .tabItem { Label("Teams", systemImage: "square.stack.3d.up.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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
