import SwiftUI

/// Écran « Préparation de l'émission » : la cabine radio du chalutier, la nuit, avec le moniteur
/// « Contrôle émetteur » et le boîtier « Commandes ». Scène de 1440 × 900 points de référence.
struct SetupScreen: View {
    let flow: SetupFlow
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            SetupWall()
            DeskSurface(top: 630)
            LogbookView(entry: flow.audio.logbook)
                .placed(x: 64, y: 648)
            EnamelMug()
                .placed(x: 470, y: 690)
            Ashtray()
                .placed(x: 1178, y: 748)
            TransmitterMonitor(flow: flow)
                .placed(x: 480, y: 78)
            CommandBox(flow: flow)
                .placed(x: 1156, y: 92)
            HangingLamp()
                .placed(x: 780, y: 20)
            SetupLighting(isScreenOn: flow.isOn)
            FilmFinish()
        }
        .frame(width: SceneMetrics.size.width, height: SceneMetrics.size.height, alignment: .topLeading)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: SetupKey.keyEquivalents) { press in
            guard let key = SetupKey(press.key) else { return .ignored }
            return flow.handle(key) ? .handled : .ignored
        }
        .onAppear {
            isFocused = true
            flow.syncWithHardware()
        }
        .onChange(of: flow.audio.inputDevices) { flow.syncWithHardware() }
        .onChange(of: flow.audio.outputDevices) { flow.syncWithHardware() }
        .onChange(of: flow.audio.selection) { flow.syncWithHardware() }
    }
}

/// Cloison de la préparation : tôles rivetées, tuyau, drapeau et nom de la station au pochoir.
private struct SetupWall: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            BulkheadPlating(
                size: CGSize(width: SceneMetrics.size.width, height: 630),
                verticalSeams: [352, 1128],
                horizontalSeams: [318]
            )
            RustStreak().frame(width: 7, height: 86).placed(x: 81, y: 334)
            RustStreak().frame(width: 9, height: 120).placed(x: 355, y: 340)
            RustStreak().frame(width: 8, height: 70).placed(x: 1133, y: 60)
            RustStreak().frame(width: 6, height: 64).placed(x: 1253, y: 334)
            CeilingPipe(brackets: [220, 980])

            PirateFlagView(width: 430)
                .rotationEffect(.degrees(-2.5))
                .placed(x: 30, y: 58)
            GafferTape()
                .frame(width: 70, height: 22)
                .rotationEffect(.degrees(-38))
                .placed(x: 40, y: 66)
            GafferTape()
                .frame(width: 70, height: 22)
                .rotationEffect(.degrees(32))
                .placed(x: 400, y: 50)

            Text(verbatim: "Radio Moustache")
                .stencilStyle(40, color: Palette.stencilPaint.opacity(0.8))
                .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                .fixedSize()
                .placed(x: 40, y: 382)
            Text("102,4 MHz · émetteur clandestin")
                .stencilStyle(17, color: Color(red: 1, green: 138 / 255, blue: 60 / 255, opacity: 0.85), tracking: 0.28)
                .fixedSize()
                .placed(x: 44, y: 432)
        }
        .frame(width: SceneMetrics.size.width, height: 630, alignment: .topLeading)
    }
}

/// Lumières de la scène : flaque de la lampe qui suit le balancement, lueur du bureau,
/// reflet vert du moniteur allumé.
private struct SetupLighting: View {
    let isScreenOn: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Ambient { time in
                GlowSpot(
                    center: CGPoint(x: 800 + LampSwing.lightOffset(at: time), y: 230),
                    radii: CGSize(width: 520, height: 440),
                    color: Color(red: 1, green: 176 / 255, blue: 86 / 255, opacity: 0.34)
                )
            }
            GlowSpot(
                center: CGPoint(x: 250, y: 740),
                radii: CGSize(width: 420, height: 300),
                color: Color(red: 1, green: 170 / 255, blue: 90 / 255, opacity: 0.16)
            )
            ZStack(alignment: .topLeading) {
                GlowSpot(center: CGPoint(x: 800, y: 360), radii: CGSize(width: 520, height: 300), color: Palette.neonGreen.opacity(0.14))
                GlowSpot(center: CGPoint(x: 800, y: 650), radii: CGSize(width: 520, height: 160), color: Palette.neonGreen.opacity(0.14))
            }
            .opacity(isScreenOn ? 1 : 0)
            .animation(.easeInOut(duration: 0.6), value: isScreenOn)
        }
        .frame(width: SceneMetrics.size.width, height: SceneMetrics.size.height, alignment: .topLeading)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension SetupKey {
    /// Touches écoutées par l'écran de préparation.
    static var keyEquivalents: Set<KeyEquivalent> {
        [.upArrow, .downArrow, .leftArrow, .rightArrow, .return, .space, .escape]
    }

    init?(_ key: KeyEquivalent) {
        switch key {
        case .upArrow: self = .up
        case .downArrow: self = .down
        case .leftArrow: self = .left
        case .rightArrow: self = .right
        case .return, .space: self = .confirm
        case .escape: self = .cancel
        default: return nil
        }
    }
}
