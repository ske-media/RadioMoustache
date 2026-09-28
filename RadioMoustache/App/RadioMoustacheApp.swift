import SwiftUI

/// Point d'entrée de Radio Moustache.
@main
struct RadioMoustacheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var audioManager: AudioManager
    @State private var setupFlow: SetupFlow

    init() {
        PirateFont.registerBundledFonts()
        let audioManager = AudioManager()
        // L'app sert aussi d'hôte aux tests unitaires : ni micro ni haut-parleurs dans ce cas.
        let services: SetupServices = AppEnvironment.isRunningTests ? .silent() : .live()
        _audioManager = State(initialValue: audioManager)
        _setupFlow = State(initialValue: SetupFlow(audio: audioManager, services: services))
    }

    var body: some Scene {
        Window("Radio Moustache", id: WindowID.studio) {
            RootView(flow: setupFlow)
                .environment(audioManager)
                .preferredColorScheme(.dark)
                .task {
                    guard !AppEnvironment.isRunningTests else { return }
                    audioManager.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: SceneMetrics.size.width, height: SceneMetrics.size.height)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .windowArrangement) {
                DiagnosticsMenuItem()
            }
        }

        // Écran technique de l'étape 1, toujours utile pour vérifier le matériel.
        Window("Diagnostic audio", id: WindowID.diagnostics) {
            DeviceDiagnosticsView()
                .environment(audioManager)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 760)
    }
}
