import SwiftUI

/// Tube cathodique du moniteur : éteint, séquence de démarrage, puis les étapes guidées de la préparation.
struct MonitorScreen: View {
    let flow: SetupFlow

    static let size = CGSize(width: 544, height: 372)

    var body: some View {
        ZStack(alignment: .topLeading) {
            EllipticalGradient(
                stops: [
                    .init(color: Color(hex: 0x10231A), location: 0),
                    .init(color: Color(hex: 0x07120D), location: 0.6),
                    .init(color: Color(hex: 0x020604), location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadiusFraction: 0,
                endRadiusFraction: 0.7
            )

            KeyframeAnimator(initialValue: WarmUp(), trigger: flow.powerOnCount) { warmUp in
                content
                    .scaleEffect(x: warmUp.scaleX, y: warmUp.scaleY)
                    .brightness(warmUp.brightness)
            } keyframes: { _ in
                KeyframeTrack(\.scaleX) {
                    MoveKeyframe(0.7)
                    LinearKeyframe(1, duration: 0.36)
                    LinearKeyframe(1, duration: 0.54)
                }
                KeyframeTrack(\.scaleY) {
                    MoveKeyframe(0.004)
                    LinearKeyframe(0.004, duration: 0.36)
                    CubicKeyframe(1.04, duration: 0.315)
                    CubicKeyframe(1, duration: 0.225)
                }
                KeyframeTrack(\.brightness) {
                    MoveKeyframe(0.8)
                    LinearKeyframe(0.6, duration: 0.36)
                    LinearKeyframe(0.2, duration: 0.315)
                    LinearKeyframe(0, duration: 0.225)
                }
            }

            ScanLines()
                .allowsHitTesting(false)
            EllipticalGradient(
                stops: [.init(color: .clear, location: 0.56), .init(color: .black.opacity(0.6), location: 1)],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.707
            )
            .allowsHitTesting(false)
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.1), location: 0),
                    .init(color: .white.opacity(0.03), location: 0.3),
                    .init(color: .clear, location: 0.45),
                ],
                startPoint: UnitPoint(x: 0.3, y: 0),
                endPoint: UnitPoint(x: 0.7, y: 1)
            )
            .allowsHitTesting(false)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 26, height: 34)))
        .contentShape(Rectangle())
        .onTapGesture {
            // Un clic sur l'écran passe la séquence de démarrage.
            flow.skipBoot()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch flow.power {
        case .off:
            ZStack {
                Circle()
                    .fill(Color(red: 160 / 255, green: 1, blue: 140 / 255, opacity: 0.2))
                    .frame(width: 8, height: 8)
                    .shadow(color: Palette.neonGreen.opacity(0.3), radius: 5)
                StandbyHint()
                    .offset(y: 86)
            }
            .frame(width: Self.size.width, height: Self.size.height)
        case .booting:
            BootText(lines: Array(flow.bootLines.prefix(flow.visibleBootLineCount)))
        case .ready:
            Ambient { time in
                StepScreen(flow: flow)
                    .opacity(Self.flickerOpacity(at: time))
            }
        }
    }

    /// Légers creux de luminosité, comme un tube qui a vécu (cycle de 3,4 s).
    static func flickerOpacity(at time: Double) -> Double {
        let phase = time.truncatingRemainder(dividingBy: 3.4) / 3.4
        switch phase {
        case 0.06..<0.07: return 0.88
        case 0.41..<0.42: return 0.94
        case 0.77..<0.78: return 0.9
        default: return 1
        }
    }
}

/// Consigne affichée tant que le secteur est coupé : elle pulse doucement.
private struct StandbyHint: View {
    var body: some View {
        Ambient { time in
            VStack(spacing: 4) {
                Text("SECTEUR COUPÉ")
                Text("ABAISSE LE LEVIER À DROITE  -->")
                Text("(OU APPUIE SUR ENTRÉE)")
            }
            .font(PirateFont.screen(21))
            .foregroundStyle(Palette.neonGreen)
            .opacity(0.3 + 0.15 * sin(2 * .pi * time / 2.4))
            .phosphorGlow()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Valeurs animées à l'allumage du tube : trait lumineux qui s'ouvre en image.
private struct WarmUp {
    var scaleX = 1.0
    var scaleY = 1.0
    var brightness = 0.0
}

/// Ligne de texte vert, éventuellement en vidéo inverse (ligne sélectionnée).
struct ScreenLine: View {
    let text: String
    var isInverted = false
    var isDimmed = false

    var body: some View {
        Text(text)
            .font(PirateFont.screen(21))
            .foregroundStyle(isInverted ? Palette.phosphorInk : Palette.neonGreen)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 25, maxHeight: 25, alignment: .leading)
            .background(isInverted ? Palette.neonGreen : .clear)
            .opacity(isDimmed ? 0.75 : 1)
    }
}

/// Curseur « _ » qui clignote une fois par seconde.
private struct BlinkingCursor: View {
    var body: some View {
        Ambient { time in
            Text(verbatim: "_")
                .font(PirateFont.screen(21))
                .foregroundStyle(Palette.neonGreen)
                .opacity(time.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0)
        }
    }
}

/// Séquence de démarrage, tapée ligne à ligne.
private struct BootText: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                ScreenLine(text: line)
            }
            BlinkingCursor()
                .padding(.leading, 4)
                .frame(height: 25)
        }
        .phosphorGlow()
        .padding(.top, 24)
        .padding(.horizontal, 22)
        .frame(width: MonitorScreen.size.width, height: MonitorScreen.size.height, alignment: .topLeading)
    }
}

/// Étape guidée : onglets, question, réponses, outil de l'étape, messages et navigation.
private struct StepScreen: View {
    let flow: SetupFlow

    static let contentWidth = MonitorScreen.size.width - 44
    /// Lignes de choix visibles sous la question.
    static let listCapacity = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                StepTabs(flow: flow)
                Text(verbatim: flow.question)
                    .font(PirateFont.screen(27))
                    .foregroundStyle(Palette.neonGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 4)
                    .frame(height: 32, alignment: .leading)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                Group {
                    if flow.step == .review, flow.advancedList == nil {
                        RecapPanel(flow: flow)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ChoiceList(flow: flow)
                                .frame(height: CGFloat(Self.listCapacity) * 25, alignment: .topLeading)
                            ToolRow(flow: flow)
                                .frame(height: 25, alignment: .leading)
                        }
                    }
                }
                .frame(height: CGFloat(Self.listCapacity) * 25 + 29, alignment: .topLeading)
                .padding(.top, 4)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(flow.statusLines.enumerated()), id: \.offset) { _, status in
                        ScreenLine(text: status)
                    }
                }
                .padding(.top, 4)
            }
            .frame(width: Self.contentWidth, alignment: .leading)
            .placed(x: 22, y: 18)

            StepFooter(flow: flow)
                .frame(width: Self.contentWidth, height: 25)
                .placed(x: 22, y: MonitorScreen.size.height - 41)
        }
        .phosphorGlow()
        .frame(width: MonitorScreen.size.width, height: MonitorScreen.size.height, alignment: .topLeading)
    }
}

/// Onglets « 1 MICRO  2 ENCEINTE  3 CASQUE  4 GO » : l'étape affichée est en vidéo inverse,
/// celles qui ne sont pas encore atteintes restent éteintes, un « ! » signale une étape à régler.
private struct StepTabs: View {
    let flow: SetupFlow

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SetupStep.allCases) { step in
                let isCurrent = step == flow.step
                let isReachable = flow.isReachable(step)
                let mark = flow.needsAttention(step) ? " !" : ""
                Button {
                    flow.goTo(step)
                } label: {
                    Text(verbatim: "\(step.rawValue) " + step.tabLabel + mark)
                        .font(PirateFont.screen(21))
                        .foregroundStyle(isCurrent ? Palette.phosphorInk : Palette.neonGreen)
                        .padding(.horizontal, 6)
                        .frame(height: 25)
                        .background(isCurrent ? Palette.neonGreen : .clear)
                        .overlay {
                            Rectangle().stroke(Palette.neonGreen.opacity(isCurrent ? 0 : 0.45), lineWidth: 1)
                        }
                        .opacity(isReachable ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!isReachable)
                .accessibilityLabel(Text("Étape \(step.rawValue) sur 4 : \(step.tabLabel)"))
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }
}

/// Appareils (ou réglages) proposés comme des boutons radio : un clic ou les flèches les prennent tout de suite.
private struct ChoiceList: View {
    let flow: SetupFlow

    var body: some View {
        let options = flow.options
        let current = options.firstIndex(where: \.isCurrent) ?? 0
        let window = SetupContent.visibleWindow(count: options.count, highlighted: current, capacity: StepScreen.listCapacity)
        VStack(alignment: .leading, spacing: 0) {
            if options.isEmpty, let list = flow.visibleList {
                ScreenLine(text: "  " + list.emptyText, isDimmed: true)
            }
            if window.lowerBound > 0 {
                ScreenLine(text: "      ...", isDimmed: true)
            }
            ForEach(window, id: \.self) { index in
                let option = options[index]
                Button {
                    flow.choose(at: index)
                } label: {
                    ScreenLine(text: (option.isCurrent ? "> (*) " : "  ( ) ") + option.text, isInverted: option.isCurrent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: option.text))
                .accessibilityAddTraits(option.isCurrent ? .isSelected : [])
            }
            if window.upperBound < options.count {
                ScreenLine(text: "      ...", isDimmed: true)
            }
        }
    }
}

/// Outil de l'étape, sous la liste : niveau du micro, ou essai de la sortie.
private struct ToolRow: View {
    let flow: SetupFlow

    var body: some View {
        if let list = flow.visibleList {
            switch list {
            case .microphone, .channel:
                LevelRow(flow: flow)
            case .mainOutput:
                OutputTestButton(flow: flow, target: .mainOutput)
            case .monitorOutput:
                if flow.audio.selection.monitorOutputUID != nil {
                    OutputTestButton(flow: flow, target: .monitorOutput)
                }
            case .latency:
                ScreenLine(text: String(localized: "PETIT = PEU DE RETARD, MAIS PLUS FRAGILE"), isDimmed: true)
            }
        }
    }
}

/// Niveau du micro en caractères : on parle, la barre se remplit.
private struct LevelRow: View {
    let flow: SetupFlow

    var body: some View {
        let meter = flow.meter
        let level = meter.status == .running ? meter.level : 0
        ScreenLine(text: String(localized: "NIVEAU") + " " + SetupContent.levelBar(level: level) + "  " + flow.levelHint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Niveau du micro"))
            .accessibilityValue(Text("\(Int((level * 100).rounded())) %"))
    }
}

/// Essai de la sortie de l'étape : la voix du Mac dit « un, deux » dessus, puis un bip.
private struct OutputTestButton: View {
    let flow: SetupFlow
    let target: TestTarget

    var body: some View {
        let isTesting = flow.testingTarget == target
        ScreenButton(isTesting ? "[ ESSAI EN COURS... ]" : "[ ESSAI : « UN, DEUX » ]", isProminent: isTesting) {
            flow.test(target)
        }
        .accessibilityHint(Text("Fait parler la sortie choisie (touche Espace)"))
    }
}

/// Récapitulatif : une ligne par étape (un clic y ramène), puis le gros bouton « Paré à émettre ! ».
private struct RecapPanel: View {
    let flow: SetupFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(flow.recapLines) { line in
                Button {
                    flow.goTo(line.step)
                } label: {
                    ScreenLine(text: line.text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: line.accessibilityText))
                .accessibilityHint(Text("Revient à cette étape"))
            }
            GoLiveButton(flow: flow)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }
}

/// Gros bouton « [ PARÉ À ÉMETTRE ! ] » : plein quand tout est prêt, en creux sinon.
private struct GoLiveButton: View {
    let flow: SetupFlow

    var body: some View {
        let isReady = flow.canGoLive
        Button {
            flow.goLive()
        } label: {
            Text("[ PARÉ À ÉMETTRE ! ]")
                .font(PirateFont.screen(30))
                .foregroundStyle(isReady ? Palette.phosphorInk : Palette.neonGreen)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(isReady ? Palette.neonGreen : .clear)
                .overlay {
                    Rectangle().stroke(Palette.neonGreen.opacity(isReady ? 0 : 0.7), lineWidth: 1)
                }
                .opacity(isReady ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isReady ? Text("Mémorise la session et ouvre la cabine radio") : Text("Corrige d'abord les alertes"))
    }
}

/// Navigation : « < Retour » à gauche, « Réglages avancés » au milieu, « Suivant > » (ou « OK ») à droite.
private struct StepFooter: View {
    let flow: SetupFlow

    var body: some View {
        ZStack {
            if flow.advancedList == nil {
                if flow.step.previous != nil {
                    ScreenButton("[ < RETOUR ]") {
                        _ = flow.back()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if flow.availableAdvancedList != nil {
                    ScreenButton("[ RÉGLAGES AVANCÉS ]") {
                        flow.openAdvancedSettings()
                    }
                }
                if flow.step.next != nil {
                    // Toujours cliquable : si l'étape n'est pas réglée, le moniteur dit pourquoi.
                    ScreenButton("[ SUIVANT > ]", isProminent: flow.canGoNext, isEnabled: flow.canGoNext) {
                        flow.next()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                ScreenButton("[ OK ]", isProminent: true) {
                    flow.closeAdvancedSettings()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// Bouton en texte vert du moniteur : plein quand c'est l'action principale, en creux sinon.
private struct ScreenButton: View {
    let title: LocalizedStringKey
    let isProminent: Bool
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, isProminent: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isProminent = isProminent
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PirateFont.screen(21))
                .foregroundStyle(isProminent ? Palette.phosphorInk : Palette.neonGreen)
                .padding(.horizontal, 10)
                .frame(height: 25)
                .background(isProminent ? Palette.neonGreen : .clear)
                .overlay {
                    Rectangle().stroke(Palette.neonGreen.opacity(isProminent ? 0 : 0.7), lineWidth: 1)
                }
                .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }
}

/// Lignes de balayage du tube.
private struct ScanLines: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: CGFloat(0), to: size.height, by: 3) {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.32)))
            }
        }
    }
}
