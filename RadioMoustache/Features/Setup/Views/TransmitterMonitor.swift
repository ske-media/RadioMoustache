import SwiftUI

/// Moniteur « Contrôle émetteur » : boîtier kaki, tube cathodique vert, plaque, voyant et boutons.
struct TransmitterMonitor: View {
    let flow: SetupFlow

    var body: some View {
        ZStack(alignment: .topLeading) {
            OliveSteel()
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.18), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 2
                        )
                }
                .frame(width: 640, height: 520)
                .shadow(color: .black.opacity(0.7), radius: 30, y: 34)
            CornerScrews(size: CGSize(width: 640, height: 520), inset: 12)

            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(hex: 0x1D1E1A), Color(hex: 0x0E0F0C)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.black.opacity(0.85), lineWidth: 3)
                        .blur(radius: 3)
                }
                .frame(width: 572, height: 400)
                .placed(x: 34, y: 32)

            MonitorScreen(flow: flow)
                .placed(x: 48, y: 46)

            TiledTexture(image: .crinkle, base: Palette.crinkle)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    Text("Contrôle émetteur")
                        .stencilStyle(17, color: Color(hex: 0xE9E2CF), tracking: 0.12)
                }
                .frame(width: 250, height: 42)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                .placed(x: 34, y: 452)

            PowerLED(isOn: flow.isOn)
                .placed(x: 318, y: 462)
            KnurledKnob(size: 44, angle: -30)
                .placed(x: 368, y: 448)
            KnurledKnob(size: 44, angle: 40)
                .placed(x: 432, y: 448)
            MaskingTape(width: 110, height: 40, angle: 3) {
                Text("PAS TOUCHE !\n— le capitaine")
                    .markerStyle(13, color: Palette.markerRed)
            }
            .placed(x: 500, y: 452)

            FrequencySticker()
                .rotationEffect(.degrees(14))
                .placed(x: 580, y: -16)
            GafferTape()
                .frame(width: 44, height: 20)
                .rotationEffect(.degrees(-80))
                .placed(x: -12, y: 200)
        }
        .frame(width: 640, height: 520, alignment: .topLeading)
    }
}

/// Voyant vert du moniteur, allumé avec le secteur.
private struct PowerLED: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Palette.neonGreen : Color(hex: 0x1D2A18))
            .overlay {
                Circle().stroke(.black.opacity(isOn ? 0 : 0.6), lineWidth: 1.5).blur(radius: 1)
            }
            .frame(width: 16, height: 16)
            .shadow(color: Palette.neonGreen.opacity(isOn ? 0.9 : 0), radius: 4)
            .shadow(color: Palette.neonGreen.opacity(isOn ? 0.5 : 0), radius: 8)
            .animation(.easeOut(duration: 0.3), value: isOn)
            .accessibilityHidden(true)
    }
}

/// Pastille orange « 102,4 MHZ » collée sur le boîtier.
private struct FrequencySticker: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color(hex: 0xFF9A4A), Palette.electricOrange, Color(hex: 0xC24A00)],
                center: UnitPoint(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: 46
            ))
            .overlay {
                VStack(spacing: 0) {
                    Text(verbatim: "102,4")
                        .font(PirateFont.stencil(20))
                    Text(verbatim: "MHZ")
                        .font(PirateFont.jost(9, weight: .bold))
                        .tracking(1.8)
                }
                .foregroundStyle(Color(hex: 0x1A0D05))
            }
            .frame(width: 74, height: 74)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
            .accessibilityLabel(Text("102,4 mégahertz"))
    }
}
