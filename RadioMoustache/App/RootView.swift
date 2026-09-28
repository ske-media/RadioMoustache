import AppKit
import SwiftUI

/// Contenu de la fenêtre principale : la préparation de l'émission, puis la cabine une fois « Paré à émettre ».
struct RootView: View {
    let flow: SetupFlow

    var body: some View {
        SceneCanvas {
            if let session = flow.confirmedSession {
                CabinPlaceholderView(session: session) {
                    flow.backToSetup()
                }
            } else {
                SetupScreen(flow: flow)
            }
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(WindowAspectRatio(ratio: SceneMetrics.aspectRatio))
    }
}

/// Garde les proportions de la fenêtre (16:10) quand on la redimensionne.
struct WindowAspectRatio: NSViewRepresentable {
    let ratio: CGSize

    func makeNSView(context: Context) -> NSView {
        AspectRatioView(ratio: ratio)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class AspectRatioView: NSView {
        private let ratio: CGSize

        init(ratio: CGSize) {
            self.ratio = ratio
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.contentAspectRatio = ratio
        }
    }
}

/// Entrée du menu Fenêtre qui ouvre le diagnostic audio de l'étape 1.
struct DiagnosticsMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Diagnostic audio…") {
            openWindow(id: WindowID.diagnostics)
        }
        .keyboardShortcut("d", modifiers: [.command, .option])
    }
}

/// Identifiants des fenêtres de l'app.
enum WindowID {
    static let studio = "studio"
    static let diagnostics = "diagnostics"
}
