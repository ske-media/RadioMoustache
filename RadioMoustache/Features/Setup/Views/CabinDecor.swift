import SwiftUI

/// Tuyau qui court au plafond de la cabine, tenu par des colliers.
struct CeilingPipe: View {
    let brackets: [CGFloat]

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x121211), location: 0),
                    .init(color: Color(hex: 0x5E5E59), location: 0.45),
                    .init(color: Color(hex: 0x2A2A28), location: 0.7),
                    .init(color: Color(hex: 0x0E0E0D), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: SceneMetrics.size.width, height: 26)
            .shadow(color: .black.opacity(0.6), radius: 6, y: 6)

            ForEach(brackets, id: \.self) { x in
                LinearGradient(colors: [Color(hex: 0x3A3A37), Color(hex: 0x1C1C1B)], startPoint: .top, endPoint: .bottom)
                    .frame(width: 22, height: 16)
                    .placed(x: x, y: 20)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Drapeau pirate de Radio Moustache (tête de mort à moustache, micros croisés).
struct PirateFlagView: View {
    let width: CGFloat

    var body: some View {
        DecorImage.pirateFlag.image
            .resizable()
            .aspectRatio(600.0 / 420.0, contentMode: .fit)
            .frame(width: width)
            .shadow(color: .black.opacity(0.65), radius: 10, y: 18)
            .accessibilityLabel(Text("Drapeau pirate de Radio Moustache : tête de mort à moustache sur deux micros croisés"))
    }
}

/// Cloison rivetée de la cabine, peinte en vert d'eau, écaillée et rouillée.
struct BulkheadPlating: View {
    let size: CGSize
    /// Positions des soudures verticales (x) et horizontales (y).
    let verticalSeams: [CGFloat]
    let horizontalSeams: [CGFloat]

    var body: some View {
        ZStack(alignment: .topLeading) {
            TiledTexture(image: .bulkhead, base: Palette.bulkhead)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .black.opacity(0.28), location: 0.55),
                    .init(color: .black.opacity(0.55), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            ForEach(verticalSeams, id: \.self) { x in
                RivetStrip(axis: .vertical)
                    .frame(width: 16, height: size.height)
                    .placed(x: x, y: 0)
                SeamShadow(axis: .vertical)
                    .frame(width: 3, height: size.height)
                    .placed(x: x + 16, y: 0)
            }
            ForEach(horizontalSeams, id: \.self) { y in
                RivetStrip(axis: .horizontal)
                    .frame(width: size.width, height: 16)
                    .placed(x: 0, y: y)
                SeamShadow(axis: .horizontal)
                    .frame(width: size.width, height: 3)
                    .placed(x: 0, y: y + 16)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// Plateau du bureau en bois sombre, avec ses lames et son chant.
struct DeskSurface: View {
    let top: CGFloat

    var body: some View {
        let height = SceneMetrics.size.height - top
        ZStack(alignment: .topLeading) {
            TiledTexture(image: .wood, base: Palette.wood)
                .frame(width: SceneMetrics.size.width, height: height)
                .placed(x: 0, y: top)
            Canvas { context, size in
                for x in stride(from: CGFloat(0), to: size.width, by: 260) {
                    context.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(.black.opacity(0.55)))
                }
            }
            .frame(width: SceneMetrics.size.width, height: height)
            .placed(x: 0, y: top)
            LinearGradient(
                colors: [Color(red: 1, green: 200 / 255, blue: 140 / 255, opacity: 0.12), .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: SceneMetrics.size.width, height: height)
            .placed(x: 0, y: top)
            LinearGradient(colors: [Color(hex: 0x7A5230), Palette.wood], startPoint: .top, endPoint: .bottom)
                .frame(width: SceneMetrics.size.width, height: 8)
                .shadow(color: .black.opacity(0.6), radius: 7, y: -6)
                .placed(x: 0, y: top - 4)
        }
        .allowsHitTesting(false)
    }
}

/// Journal de bord tapé à la machine : la dernière émission et un mot au marqueur.
struct LogbookView: View {
    let entry: LogbookEntry?

    var body: some View {
        ZStack(alignment: .topLeading) {
            TiledTexture(image: .paper, base: Palette.logbookPaper)
            Canvas { context, size in
                for y in stride(from: CGFloat(25), to: size.height, by: 26) {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                 with: .color(Color(red: 70 / 255, green: 110 / 255, blue: 160 / 255, opacity: 0.28)))
                }
                context.fill(Path(CGRect(x: 38, y: 0, width: 1, height: size.height)),
                             with: .color(Color(red: 190 / 255, green: 40 / 255, blue: 40 / 255, opacity: 0.45)))
            }
            Text("JOURNAL DE BORD")
                .font(PirateFont.typewriter(15))
                .tracking(0.6)
                .foregroundStyle(Palette.typewriterInk)
                .placed(x: 50, y: 12)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(LogbookPage.lines(for: entry).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(PirateFont.typewriter(13))
                        .foregroundStyle(Palette.typewriterInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 26, alignment: .leading)
                }
            }
            .frame(width: 306, alignment: .leading)
            .placed(x: 50, y: 40)
            Text(LogbookPage.note(for: entry))
                .markerStyle(18, color: Palette.markerRed)
                .fixedSize()
                .rotationEffect(.degrees(-6))
                .placed(x: 196, y: 176)
        }
        .frame(width: 370, height: 228, alignment: .topLeading)
        .shadow(color: .black.opacity(0.55), radius: 9, y: 10)
        .rotationEffect(.degrees(-3))
        .accessibilityElement(children: .combine)
    }
}

/// Tasse émaillée « RM » qui fume.
struct EnamelMug: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RisingPuffs(
                puffs: [
                    .init(origin: CGPoint(x: 38, y: 150), diameter: 34, alpha: 0.55, delay: 0),
                    .init(origin: CGPoint(x: 50, y: 156), diameter: 28, alpha: 0.5, delay: 2.4),
                ],
                period: 5,
                travel: CGSize(width: 12, height: -120),
                scales: 0.6...2.1,
                peakOpacity: 0.26,
                peakAt: 0.2,
                blur: 6,
                area: CGSize(width: 130, height: 200)
            )
            .placed(x: -20, y: -180)

            Path { path in
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: 5, y: 3))
                path.addArc(center: CGPoint(x: 5, y: 17), radius: 14, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                path.addLine(to: CGPoint(x: 0, y: 31))
            }
            .stroke(Color(hex: 0xD6D0C2), lineWidth: 6)
            .frame(width: 22, height: 34)
            .placed(x: 60, y: 22)

            UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 4)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0xCFC9BB), location: 0),
                        .init(color: Color(hex: 0xF4F1EA), location: 0.35),
                        .init(color: Color(hex: 0xDDD7C9), location: 0.7),
                        .init(color: Color(hex: 0xA9A396), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 64, height: 78)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 8)
                .placed(x: 4, y: 6)

            Ellipse()
                .fill(Color(hex: 0x1F3A66))
                .overlay {
                    Ellipse().stroke(.black.opacity(0.35), lineWidth: 1)
                }
                .frame(width: 64, height: 8)
                .placed(x: 4, y: 4)

            Text(verbatim: "RM")
                .font(PirateFont.stencil(13))
                .foregroundStyle(Color(hex: 0x1F3A66))
                .placed(x: 14, y: 36)
        }
        .frame(width: 76, height: 86, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// Cendrier, cigarette qui se consume et fumée qui monte.
struct Ashtray: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RisingPuffs(
                puffs: [
                    .init(origin: CGPoint(x: 96, y: 244), diameter: 40, alpha: 0.5, delay: 0),
                    .init(origin: CGPoint(x: 104, y: 250), diameter: 32, alpha: 0.45, delay: 2.3),
                    .init(origin: CGPoint(x: 92, y: 248), diameter: 36, alpha: 0.45, delay: 4.6),
                ],
                period: 7,
                travel: CGSize(width: -44, height: -200),
                scales: 0.5...2.6,
                peakOpacity: 0.34,
                peakAt: 0.15,
                color: Color(red: 0.86, green: 0.86, blue: 0.84),
                blur: 7,
                area: CGSize(width: 200, height: 290)
            )
            .placed(x: 0, y: -270)

            Ellipse()
                .fill(EllipticalGradient(
                    stops: [
                        .init(color: Color(hex: 0x2A2A28), location: 0),
                        .init(color: Color(hex: 0x2A2A28), location: 0.45),
                        .init(color: Color(hex: 0x8D8C86), location: 0.52),
                        .init(color: Color(hex: 0x3F3E3A), location: 0.7),
                        .init(color: Color(hex: 0x1A1A18), location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.62
                ))
                .frame(width: 130, height: 44)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 8)
                .placed(x: 10, y: 36)

            Capsule()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0xD9C9A0), location: 0),
                        .init(color: Color(hex: 0xD9C9A0), location: 0.22),
                        .init(color: Color(hex: 0xF3EFE4), location: 0.22),
                        .init(color: Color(hex: 0xF3EFE4), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 72, height: 8)
                .rotationEffect(.degrees(-12))
                .placed(x: 44, y: 34)

            Ambient { time in
                let pulse = 0.5 + 0.5 * sin(2 * .pi * time / 4.4)
                Circle()
                    .fill(Palette.electricOrange)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(hex: 0xFFB070).opacity(0.6 + 0.4 * pulse), radius: 2 + 2 * pulse)
                    .shadow(color: Palette.electricOrange.opacity(0.6 + 0.3 * pulse), radius: 5 + 4 * pulse)
            }
            .placed(x: 111, y: 22)
        }
        .frame(width: 150, height: 90, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// Lampe suspendue à abat-jour émaillé, qui se balance doucement.
struct HangingLamp: View {
    var body: some View {
        Ambient { time in
            lamp.rotationEffect(.degrees(LampSwing.angle(at: time)), anchor: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var lamp: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(hex: 0x0C0C0B))
                .frame(width: 2, height: 96)
                .placed(x: 19, y: 0)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0x4A4A46), Color(hex: 0x1C1C1B)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 14)
                .placed(x: 12, y: 92)
            PolygonShape.lampShade
                .fill(LinearGradient(colors: [Color(hex: 0x33503F), Color(hex: 0x1A2A21)], startPoint: .top, endPoint: .bottom))
                .frame(width: 128, height: 50)
                .placed(x: -44, y: 104)
            Ellipse()
                .fill(EllipticalGradient(
                    stops: [
                        .init(color: Color(hex: 0xFFF7DE), location: 0),
                        .init(color: Color(hex: 0xFFD48A), location: 0.45),
                        .init(color: Color(red: 1, green: 170 / 255, blue: 80 / 255, opacity: 0.4), location: 0.7),
                        .init(color: .clear, location: 0.8),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.2),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8
                ))
                .frame(width: 120, height: 12)
                .placed(x: -40, y: 148)
        }
        .frame(width: 40, height: 200, alignment: .topLeading)
    }
}

/// Vignettage et grain de pellicule sur toute la scène.
struct FilmFinish: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                stops: [.init(color: .clear, location: 0.46), .init(color: .black.opacity(0.66), location: 1)],
                center: UnitPoint(x: 0.52, y: 0.42),
                startRadiusFraction: 0,
                endRadiusFraction: 0.78
            )
            TiledTexture(image: .grain)
                .blendMode(.overlay)
                .opacity(0.3)
        }
        .frame(width: SceneMetrics.size.width, height: SceneMetrics.size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
