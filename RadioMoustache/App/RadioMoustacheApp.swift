import SwiftUI

/// Point d'entrée de Radio Moustache.
@main
struct RadioMoustacheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var audioManager = AudioManager()

    var body: some Scene {
        Window("Radio Moustache", id: "studio") {
            // Écran provisoire de l'étape 1, remplacé par la modale vintage à l'étape 2.
            DeviceDiagnosticsView()
                .environment(audioManager)
                .preferredColorScheme(.dark)
                .task {
                    // L'app sert d'hôte aux tests unitaires : pas d'accès au matériel dans ce cas.
                    guard !AppEnvironment.isRunningTests else { return }
                    audioManager.start()
                }
        }
        .defaultSize(width: 1100, height: 760)
    }
}
