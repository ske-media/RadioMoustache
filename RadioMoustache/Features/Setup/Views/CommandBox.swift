import SwiftUI

/// Boîtier « Commandes » : levier « SECTEUR », œil magique et boutons d'essai.
struct CommandBox: View {
    let flow: SetupFlow

    static let size = CGSize(width: 256, height: 524)

    var body: some View {
        ZStack(alignment: .topLeading) {
            TiledTexture(image: .crinkle, base: Palette.crinkle)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.12), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 2
                        )
                }
                .frame(width: Self.size.width, height: Self.size.height)
                .shadow(color: .black.opacity(0.7), radius: 18, y: 20)
            CornerScrews(size: Self.size)

            Text("Commandes")
                .stencilStyle(18, color: Color(hex: 0xE9E2CF), tracking: 0.14)
                .frame(width: Self.size.width)
                .placed(x: 0, y: 22)

            KnifeSwitch(isOn: flow.isOn, sparkTrigger: flow.powerOnCount) {
                flow.togglePower()
            }
            .placed(x: 63, y: 56)

            MaskingTape(width: 144, height: 30, angle: -2) {
                (flow.isOn ? Text("Secteur : ON") : Text("Allume-moi !"))
                    .markerStyle(15)
            }
            .placed(x: 56, y: 236)

            MagicEye(meter: flow.meter, isLit: flow.isOn)
                .placed(x: 78, y: 284)
            MaskingTape(width: 116, height: 26, angle: 1.5) {
                Text("Niveau micro").markerStyle(13)
            }
            .placed(x: 70, y: 390)

            TestButton(title: "Essai enceinte", capColors: [Color(hex: 0xC9412E), Palette.deepBordeaux], isLit: flow.testingTarget == .mainOutput, tapeAngle: -1.5) {
                flow.test(.mainOutput)
            }
            .placed(x: 22, y: 430)
            TestButton(title: "Essai casque", capColors: [Color(hex: 0x3C3C3A), Color(hex: 0x0C0C0B)], isLit: flow.testingTarget == .monitorOutput, tapeAngle: 1) {
                flow.test(.monitorOutput)
            }
            .placed(x: 22, y: 474)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
}

/// Interrupteur à couteau en cuivre sur socle de porcelaine.
struct KnifeSwitch: View {
    let isOn: Bool
    /// Change à chaque mise sous tension : déclenche les étincelles.
    let sparkTrigger: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0xF4EFE2), location: 0),
                            .init(color: Color(hex: 0xD9D1BD), location: 0.6),
                            .init(color: Color(hex: 0xB3A992), location: 1),
                        ],
                        startPoint: UnitPoint(x: 0.3, y: 0),
                        endPoint: UnitPoint(x: 0.7, y: 1)
                    ))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.7), lineWidth: 1).padding(1)
                    }
                    .frame(width: 130, height: 172)
                    .shadow(color: .black.opacity(0.6), radius: 7, y: 8)
                CornerScrews(size: CGSize(width: 130, height: 172), inset: 8)

                CopperJaw().placed(x: 50, y: 14)
                CopperJaw().placed(x: 72, y: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color(hex: 0xD58C52), Color(hex: 0x8A4516)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 38, height: 24)
                    .shadow(color: .black.opacity(0.5), radius: 1.5, y: 2)
                    .placed(x: 46, y: 130)

                blade
                    .rotationEffect(.degrees(isOn ? 0 : -58), anchor: UnitPoint(x: 0.5, y: 96.0 / 102.0))
                    .animation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.35), value: isOn)
                    .placed(x: 59, y: 40)

                SparkBurst(trigger: sparkTrigger)
                    .placed(x: 40, y: 4)
            }
            .frame(width: 130, height: 172, alignment: .topLeading)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Secteur"))
        .accessibilityValue(isOn ? Text("allumé") : Text("éteint"))
        .accessibilityHint(isOn ? Text("Coupe l'émetteur") : Text("Met l'émetteur sous tension"))
    }

    /// Lame de cuivre et sa poignée noire, qui pivotent autour de la charnière.
    private var blade: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x7A3B12), location: 0),
                        .init(color: Color(hex: 0xF0B27A), location: 0.45),
                        .init(color: Color(hex: 0xB8652C), location: 0.7),
                        .init(color: Color(hex: 0x5E2A0A), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 12, height: 102)
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 3)
            UnevenRoundedRectangle(topLeadingRadius: 11, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 11)
                .fill(RadialGradient(
                    colors: [Color(hex: 0x555552), Color(hex: 0x151514)],
                    center: UnitPoint(x: 0.4, y: 0.28),
                    startRadius: 0,
                    endRadius: 25
                ))
                .frame(width: 26, height: 36)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 4)
                .placed(x: -7, y: -30)
            Circle()
                .fill(Color(hex: 0x3A1A06))
                .frame(width: 6, height: 6)
                .placed(x: 3, y: 92)
        }
        .frame(width: 12, height: 102, alignment: .topLeading)
    }
}

/// Mâchoire de cuivre qui reçoit la lame.
private struct CopperJaw: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x6E3510), location: 0),
                    .init(color: Color(hex: 0xE9A86F), location: 0.45),
                    .init(color: Color(hex: 0xA85A24), location: 0.7),
                    .init(color: Color(hex: 0x512405), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: 8, height: 36)
    }
}

/// Étincelles quand la lame touche les mâchoires.
struct SparkBurst: View {
    let trigger: Int

    /// Durée de la gerbe, décalages compris.
    private static let duration = 0.67

    var body: some View {
        KeyframeAnimator(initialValue: 1.0, trigger: trigger) { progress in
            ZStack(alignment: .topLeading) {
                spark(progress: progress, delay: 0) {
                    Circle().fill(RadialGradient(
                        stops: [
                            .init(color: .white, location: 0.2),
                            .init(color: Color(hex: 0xFFD27A), location: 0.35),
                            .init(color: Palette.electricOrange.opacity(0.7), location: 0.55),
                            .init(color: .clear, location: 0.72),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 15.5
                    ))
                    .frame(width: 22, height: 22)
                }
                .placed(x: 14, y: 12)
                spark(progress: progress, delay: 0.08) {
                    Circle().fill(Color(hex: 0xFFE2A8)).frame(width: 10, height: 10)
                }
                .placed(x: 0, y: 2)
                spark(progress: progress, delay: 0.12) {
                    Circle().fill(Color(hex: 0xFFF3D6)).frame(width: 8, height: 8)
                }
                .placed(x: 42, y: 0)
            }
            .frame(width: 60, height: 40, alignment: .topLeading)
        } keyframes: { _ in
            KeyframeTrack {
                MoveKeyframe(0)
                LinearKeyframe(1, duration: Self.duration)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Une étincelle : grossit de 0,4 à 2 fois sa taille en s'éteignant (0,55 s).
    private func spark<Content: View>(progress: Double, delay: Double, @ViewBuilder content: () -> Content) -> some View {
        let local = min(max((progress * Self.duration - delay) / 0.55, 0), 1)
        let eased = 1 - (1 - local) * (1 - local)
        let isVisible = progress < 1 && progress * Self.duration >= delay
        return content()
            .scaleEffect(0.4 + 1.6 * eased)
            .opacity(isVisible ? 1 - eased : 0)
    }
}

/// Œil magique : trèfle vert dont l'ombre se referme quand le micro capte du son.
struct MagicEye: View {
    let meter: any InputLevelMonitoring
    let isLit: Bool

    var body: some View {
        let level = meter.status == .running ? meter.level : 0
        ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0xF4F4F0), location: 0),
                        .init(color: Color(hex: 0xA7ABA8), location: 0.42),
                        .init(color: Color(hex: 0x4D524F), location: 0.72),
                        .init(color: Color(hex: 0x1C1F1E), location: 1),
                    ],
                    center: UnitPoint(x: 0.38, y: 0.32),
                    startRadius: 0,
                    endRadius: 62
                ))
                .shadow(color: .black.opacity(0.6), radius: 7, y: 6)

            ZStack {
                Circle().fill(RadialGradient(stops: glassStops, center: .center, startRadius: 0, endRadius: 55))
                EyeShadowShape(halfAngle: LevelMeterMath.eyeShadowHalfAngle(level: level))
                    .fill(Color(red: 3 / 255, green: 10 / 255, blue: 2 / 255, opacity: 0.94))
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x1A2A14), Color(hex: 0x050A04)], center: .center, startRadius: 0, endRadius: 11))
                    .frame(width: 22, height: 22)
            }
            .frame(width: 78, height: 78)
            .clipShape(Circle())
            .shadow(color: Palette.neonGreen.opacity(isLit ? 0.6 : 0), radius: 10)
        }
        .frame(width: 100, height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Œil magique, niveau du micro"))
        .accessibilityValue(Text("\(Int((level * 100).rounded())) %"))
    }

    private var glassStops: [Gradient.Stop] {
        if isLit {
            [
                .init(color: Color(hex: 0x0B1A06), location: 0),
                .init(color: Color(hex: 0x0B1A06), location: 0.26),
                .init(color: Palette.neonGreen, location: 0.28),
                .init(color: Color(hex: 0x28B30A), location: 0.52),
                .init(color: Color(hex: 0x0E4A05), location: 0.78),
                .init(color: Color(hex: 0x041003), location: 1),
            ]
        } else {
            [
                .init(color: Color(hex: 0x0A0F09), location: 0),
                .init(color: Color(hex: 0x0A0F09), location: 0.26),
                .init(color: Color(hex: 0x1C2A18), location: 0.28),
                .init(color: Color(hex: 0x111A0F), location: 0.6),
                .init(color: Color(hex: 0x060906), location: 1),
            ]
        }
    }
}

/// Ombre de l'œil magique : secteur qui part du centre vers le haut.
struct EyeShadowShape: Shape {
    /// Demi-ouverture du secteur, en degrés.
    let halfAngle: Double

    nonisolated func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: max(rect.width, rect.height),
            startAngle: .degrees(-90 - halfAngle),
            endAngle: .degrees(-90 + halfAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// Bouton d'essai chromé, son voyant et son étiquette.
struct TestButton: View {
    let title: LocalizedStringKey
    let capColors: [Color]
    let isLit: Bool
    let tapeAngle: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0xF4F4F0), location: 0),
                            .init(color: Color(hex: 0xA5AAA7), location: 0.45),
                            .init(color: Color(hex: 0x4B504E), location: 0.8),
                        ],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: 26
                    ))
                    .overlay {
                        Circle()
                            .fill(RadialGradient(colors: capColors, center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 14))
                            .frame(width: 24, height: 24)
                    }
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 4)
                IndicatorLamp(glow: isLit ? .orange : .off, size: 16)
                    .animation(.easeOut(duration: 0.2), value: isLit)
                    .placed(x: 186, y: 11)
                MaskingTape(width: 128, height: 26, angle: tapeAngle) {
                    Text(title).markerStyle(13)
                }
                .placed(x: 48, y: 6)
            }
            .frame(width: 212, height: 38, alignment: .topLeading)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(title))
    }
}
