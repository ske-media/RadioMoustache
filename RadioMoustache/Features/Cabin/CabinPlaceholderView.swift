import SwiftUI

/// Cabine radio provisoire, affichée après « Paré à émettre ». L'étape 3 y installera l'ON AIR, la console,
/// la platine et les cartouches ; pour l'instant elle résume la session validée.
struct CabinPlaceholderView: View {
    let session: SessionConfiguration
    let onBack: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            BulkheadPlating(
                size: SceneMetrics.size,
                verticalSeams: [472, 1112],
                horizontalSeams: [264]
            )
            CeilingPipe(brackets: [300, 1100])
            PirateFlagView(width: 360)
                .rotationEffect(.degrees(-3))
                .placed(x: 60, y: 60)
            Text(verbatim: "Radio Moustache")
                .stencilStyle(34, color: Palette.stencilPaint.opacity(0.8))
                .fixedSize()
                .placed(x: 64, y: 330)
            MaskingTape(width: 330, height: 44, angle: -2) {
                Text("Cabine en chantier : étape 3").markerStyle(20, color: Palette.markerRed)
            }
            .placed(x: 70, y: 390)

            SessionSummary(session: session, onBack: onBack)
                .placed(x: 560, y: 150)
            FilmFinish()
        }
        .frame(width: SceneMetrics.size.width, height: SceneMetrics.size.height, alignment: .topLeading)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.escape) {
            onBack()
            return .handled
        }
        .onAppear { isFocused = true }
    }
}

/// Écran vert qui récapitule la session validée.
private struct SessionSummary: View {
    let session: SessionConfiguration
    let onBack: () -> Void

    private static let screenSize = CGSize(width: 680, height: 420)

    var body: some View {
        ZStack(alignment: .topLeading) {
            OliveSteel()
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .frame(width: 740, height: 500)
                .shadow(color: .black.opacity(0.7), radius: 30, y: 34)
            CornerScrews(size: CGSize(width: 740, height: 500), inset: 12)

            ZStack(alignment: .topLeading) {
                EllipticalGradient(
                    stops: [
                        .init(color: Color(hex: 0x10231A), location: 0),
                        .init(color: Color(hex: 0x020604), location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.45),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        ScreenLine(text: line)
                    }
                    Color.clear.frame(height: 20)
                    Button(action: onBack) {
                        Text("[ RETOUR À LA PRÉPARATION ]")
                            .font(PirateFont.screen(21))
                            .foregroundStyle(Palette.phosphorInk)
                            .padding(.horizontal, 10)
                            .frame(height: 25)
                            .background(Palette.neonGreen)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                }
                .phosphorGlow()
                .padding(.top, 24)
                .padding(.horizontal, 22)
            }
            .frame(width: Self.screenSize.width, height: Self.screenSize.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 26, height: 34)))
            .placed(x: 30, y: 30)
        }
        .frame(width: 740, height: 500, alignment: .topLeading)
    }

    private var lines: [String] {
        let monitor = session.monitorOutput.map { $0.name.screenUppercased } ?? String(localized: "AUCUN")
        return [
            "  " + String(localized: "SESSION VALIDÉE · 102,4 MHZ"),
            "  ===========================",
            "  " + BootScript.dotted(String(localized: "MICRO"), session.input.name.screenUppercased),
            "  " + BootScript.dotted(String(localized: "CANAL"), session.inputChannels.label(on: session.input).screenUppercased),
            "  " + BootScript.dotted(String(localized: "ENCEINTE"), session.mainOutput.name.screenUppercased),
            "  " + BootScript.dotted(String(localized: "CASQUE"), monitor),
            "  " + BootScript.dotted(String(localized: "LATENCE"), String(localized: "\(Int(session.bufferFrameSize)) ÉCHANTILLONS")),
            "",
            "  " + String(localized: "LA CABINE ARRIVE À L'ÉTAPE 3 :"),
            "  " + String(localized: "ON AIR, CONSOLE, PLATINE ET CARTOUCHES."),
        ]
    }
}
