import SwiftUI

/// Tube cathodique du moniteur : éteint, séquence de démarrage, puis menu vert et listes de choix.
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
            Circle()
                .fill(Color(red: 160 / 255, green: 1, blue: 140 / 255, opacity: 0.2))
                .frame(width: 8, height: 8)
                .shadow(color: Palette.neonGreen.opacity(0.3), radius: 5)
                .frame(width: Self.size.width, height: Self.size.height)
        case .booting:
            BootText(lines: Array(flow.bootLines.prefix(flow.visibleBootLineCount)))
        case .ready:
            Ambient { time in
                Group {
                    if let row = flow.openRow {
                        OptionList(flow: flow, row: row)
                    } else {
                        MainMenu(flow: flow)
                    }
                }
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

/// Menu principal : micro, canal, enceinte, casque, latence, alertes et « Paré à émettre ».
private struct MainMenu: View {
    let flow: SetupFlow

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenLine(text: "  " + String(localized: "PRÉPARATION DE L'ÉMISSION · 102,4 MHZ"))
                ScreenLine(text: "  =====================================")
                ForEach(flow.menuLines) { line in
                    Button {
                        flow.activate(line.row)
                    } label: {
                        ScreenLine(text: line.text, isInverted: line.row == flow.focusedRow)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: line.accessibilityText))
                }
                Color.clear.frame(height: 8)
                ForEach(Array(flow.statusLines.enumerated()), id: \.offset) { _, status in
                    ScreenLine(text: "  " + status)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 22)

            ScreenLine(text: String(localized: "CLIQUE UNE LIGNE POUR CHANGER · FLÈCHES ET ENTRÉE"), isDimmed: true)
                .frame(width: MonitorScreen.size.width - 48)
                .placed(x: 22, y: MonitorScreen.size.height - 75)

            HStack(spacing: 0) {
                Text(verbatim: flow.focusedRow == .goLive ? "> " : "  ")
                    .font(PirateFont.screen(21))
                    .foregroundStyle(Palette.neonGreen)
                GoLiveButton(flow: flow)
                Spacer(minLength: 8)
                (flow.audio.lastSessionRestored ? Text("SESSION RETROUVÉE") : Text("NOUVELLE SESSION"))
                    .font(PirateFont.screen(21))
                    .foregroundStyle(Palette.neonGreen)
                BlinkingCursor()
            }
            .frame(width: MonitorScreen.size.width - 48, height: 25)
            .placed(x: 22, y: MonitorScreen.size.height - 41)
        }
        .phosphorGlow()
        .frame(width: MonitorScreen.size.width, height: MonitorScreen.size.height, alignment: .topLeading)
    }
}

/// Bouton « [ PARÉ À ÉMETTRE ] » : plein quand tout est prêt, en creux sinon.
private struct GoLiveButton: View {
    let flow: SetupFlow

    var body: some View {
        let isReady = flow.canGoLive
        Button {
            flow.activate(.goLive)
        } label: {
            Text("[ PARÉ À ÉMETTRE ]")
                .font(PirateFont.screen(21))
                .foregroundStyle(isReady ? Palette.phosphorInk : Palette.neonGreen)
                .padding(.horizontal, 10)
                .frame(height: 25)
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

/// Liste des choix d'une ligne, affichée dans l'écran à la place du menu.
private struct OptionList: View {
    let flow: SetupFlow
    let row: SetupRow

    /// Nombre de lignes de choix qui tiennent sous le titre.
    private static let capacity = 9

    var body: some View {
        let options = flow.openOptions
        let window = SetupMenu.visibleWindow(
            count: options.count,
            highlighted: flow.highlightedOption,
            capacity: Self.capacity
        )
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenLine(text: "  " + row.listTitle)
                ScreenLine(text: "  " + String(repeating: "=", count: row.listTitle.count))
                if window.lowerBound > 0 {
                    ScreenLine(text: "    ...", isDimmed: true)
                }
                ForEach(window, id: \.self) { index in
                    let option = options[index]
                    let isHighlighted = index == flow.highlightedOption
                    Button {
                        flow.chooseOption(at: index)
                    } label: {
                        ScreenLine(
                            text: (isHighlighted ? "> " : "  ") + (option.isCurrent ? "• " : "  ") + option.text,
                            isInverted: isHighlighted
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        if isHovering { flow.highlightOption(at: index) }
                    }
                    .accessibilityLabel(Text(verbatim: option.text))
                    .accessibilityAddTraits(option.isCurrent ? .isSelected : [])
                }
                if window.upperBound < options.count {
                    ScreenLine(text: "    ...", isDimmed: true)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 22)

            ScreenLine(text: String(localized: "FLÈCHES : CHOISIR · ENTRÉE : VALIDER · ÉCHAP : RETOUR"), isDimmed: true)
                .frame(width: MonitorScreen.size.width - 48)
                .placed(x: 22, y: MonitorScreen.size.height - 75)

            Button {
                flow.closeList()
            } label: {
                Text("[ RETOUR ]")
                    .font(PirateFont.screen(21))
                    .foregroundStyle(Palette.neonGreen)
                    .padding(.horizontal, 10)
                    .frame(height: 25)
                    .overlay {
                        Rectangle().stroke(Palette.neonGreen.opacity(0.7), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .placed(x: 44, y: MonitorScreen.size.height - 41)
        }
        .phosphorGlow()
        .frame(width: MonitorScreen.size.width, height: MonitorScreen.size.height, alignment: .topLeading)
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
