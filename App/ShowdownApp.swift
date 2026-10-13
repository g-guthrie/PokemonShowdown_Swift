import AVFoundation
import SwiftUI

@main
struct ShowdownApp: App {
    init() {
        // Battle sounds mix with other audio and respect the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    var body: some Scene {
        WindowGroup {
            ShowdownScreen()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

/// Hosts the UIKit controller that owns the web view.
struct ShowdownScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ShowdownViewController {
        ShowdownViewController()
    }

    func updateUIViewController(_ controller: ShowdownViewController, context: Context) {}
}
