import SwiftUI

/// Dimensions de référence des scènes, en points : tout y est placé, puis mis à l'échelle de la fenêtre.
enum SceneMetrics {
    static let size = CGSize(width: 1440, height: 900)
    /// Proportions de la fenêtre (16:10).
    static let aspectRatio = CGSize(width: 16, height: 10)
}

extension View {
    /// Place la vue dans la scène : son coin haut gauche en (x, y), en points de référence.
    func placed(x: CGFloat, y: CGFloat) -> some View {
        offset(x: x, y: y)
    }

    /// Lueur verte des écrans cathodiques.
    func phosphorGlow(_ color: Color = Palette.neonGreen) -> some View {
        shadow(color: color, radius: 1)
            .shadow(color: color.opacity(0.55), radius: 4)
            .shadow(color: color.opacity(0.22), radius: 9)
    }

    /// Texte écrit au marqueur.
    func markerStyle(_ size: CGFloat, color: Color = Palette.markerInk) -> some View {
        font(PirateFont.marker(size))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }

    /// Lettres peintes au pochoir.
    func stencilStyle(_ size: CGFloat, color: Color = Palette.stencilPaint, tracking: CGFloat = 0.06) -> some View {
        font(PirateFont.stencil(size))
            .tracking(size * tracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// Scène dessinée dans le repère de référence (1440 × 900), agrandie ou réduite pour remplir la fenêtre
/// sans être déformée (bandes sombres si les proportions diffèrent, en plein écran).
struct SceneCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let size = SceneMetrics.size
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            content
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Palette.night)
        .ignoresSafeArea()
    }
}

/// Polygone décrit en fractions de son cadre, comme un `clip-path: polygon()` en CSS.
struct PolygonShape: Shape {
    let points: [UnitPoint]

    init(_ points: [(CGFloat, CGFloat)]) {
        self.points = points.map { UnitPoint(x: $0.0, y: $0.1) }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: Self.location(of: first, in: rect))
        for point in points.dropFirst() {
            path.addLine(to: Self.location(of: point, in: rect))
        }
        path.closeSubpath()
        return path
    }

    nonisolated private static func location(of point: UnitPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }

    /// Bords déchirés du scotch de masquage.
    static let maskingTape = PolygonShape([
        (0, 0.06), (0.03, 0), (0.97, 0), (1, 0.08), (0.98, 0.32), (1, 0.58), (0.97, 0.82),
        (1, 1), (0.03, 1), (0, 0.92), (0.02, 0.68), (0, 0.42), (0.03, 0.2),
    ])
    /// Bords du gaffer.
    static let gaffer = PolygonShape([
        (0, 0.08), (0.04, 0), (0.96, 0), (1, 0.1), (0.97, 0.42), (1, 0.72), (0.96, 1),
        (0.04, 1), (0, 0.9), (0.03, 0.55),
    ])
    /// Abat-jour de la lampe suspendue.
    static let lampShade = PolygonShape([(0.34, 0), (0.66, 0), (1, 1), (0, 1)])
}

/// Matière exportée de la maquette, répétée en mosaïque sur une couleur de fond.
struct TiledTexture: View {
    let image: DecorImage
    var base: Color = .clear

    var body: some View {
        base.overlay {
            image.image.resizable(resizingMode: .tile)
        }
    }
}

/// Tôle kaki du moniteur : tôle froissée teintée.
struct OliveSteel: View {
    var body: some View {
        ZStack {
            TiledTexture(image: .crinkle, base: Palette.olive)
            LinearGradient(
                colors: [
                    Color(red: 86 / 255, green: 98 / 255, blue: 66 / 255, opacity: 0.62),
                    Color(red: 58 / 255, green: 66 / 255, blue: 44 / 255, opacity: 0.7),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Bout de scotch de masquage portant un texte au marqueur.
struct MaskingTape<Label: View>: View {
    let width: CGFloat
    let height: CGFloat
    var angle: Double = 0
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            TiledTexture(image: .paper, base: Palette.maskingTape)
                .clipShape(PolygonShape.maskingTape)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            label
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(angle))
    }
}

/// Bande de gaffer noir.
struct GafferTape: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x3D3D3B), location: 0),
                .init(color: Color(hex: 0x232322), location: 0.55),
                .init(color: Color(hex: 0x30302E), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.14)).frame(height: 1)
        }
        .clipShape(PolygonShape.gaffer)
        .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
    }
}

/// Vis à tête fendue.
struct Screw: View {
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: Color(hex: 0xE9EBE8), location: 0),
                    .init(color: Color(hex: 0x7D827F), location: 0.6),
                    .init(color: Color(hex: 0x3C403E), location: 1),
                ],
                center: UnitPoint(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: size * 0.75
            ))
            .overlay {
                Capsule()
                    .fill(.black.opacity(0.55))
                    .frame(width: size * 0.8, height: size * 0.2)
                    .rotationEffect(.degrees(35))
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.6), radius: 0.5, y: 1)
    }
}

/// Quatre vis aux coins d'une plaque.
struct CornerScrews: View {
    let size: CGSize
    var inset: CGFloat = 10
    var screwSize: CGFloat = 10

    var body: some View {
        let right = size.width - inset - screwSize
        let bottom = size.height - inset - screwSize
        ZStack(alignment: .topLeading) {
            Screw(size: screwSize).placed(x: inset, y: inset)
            Screw(size: screwSize).placed(x: right, y: inset)
            Screw(size: screwSize).placed(x: inset, y: bottom)
            Screw(size: screwSize).placed(x: right, y: bottom)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Rangée de rivets le long d'une soudure de la cloison.
struct RivetStrip: View {
    let axis: Axis
    var spacing: CGFloat = 34

    var body: some View {
        Canvas { context, size in
            let length = axis == .horizontal ? size.width : size.height
            let count = Int((length / spacing).rounded(.up))
            let radius: CGFloat = 6.8
            for index in 0..<count {
                let along = CGFloat(index) * spacing + spacing / 2
                let center = axis == .horizontal
                    ? CGPoint(x: along, y: size.height / 2)
                    : CGPoint(x: size.width / 2, y: along)
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(Self.rivet, center: center, startRadius: 0, endRadius: radius)
                )
            }
        }
    }

    private static var rivet: Gradient {
        Gradient(stops: [
            .init(color: Color(hex: 0xA6D6CD), location: 0.18),
            .init(color: Color(hex: 0x4F8981), location: 0.32),
            .init(color: Color(hex: 0x1E3F3B), location: 0.68),
            .init(color: .black.opacity(0.45), location: 0.82),
            .init(color: .clear, location: 1),
        ])
    }
}

/// Ombre d'une soudure entre deux tôles.
struct SeamShadow: View {
    let axis: Axis

    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0.6), Color(red: 160 / 255, green: 215 / 255, blue: 205 / 255, opacity: 0.16)],
            startPoint: axis == .vertical ? .leading : .top,
            endPoint: axis == .vertical ? .trailing : .bottom
        )
    }
}

/// Coulure de rouille sous une soudure.
struct RustStreak: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 128 / 255, green: 60 / 255, blue: 20 / 255, opacity: 0.8), location: 0),
                .init(color: Color(red: 128 / 255, green: 60 / 255, blue: 20 / 255, opacity: 0.3), location: 0.45),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 1)
    }
}

/// Bouton moleté en bakélite.
struct KnurledKnob: View {
    var size: CGFloat = 44
    var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(gradient: Self.knurl, center: .center))
                .shadow(color: .black.opacity(0.6), radius: 4, y: 4)
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(hex: 0x5D5D5A), location: 0),
                        .init(color: Color(hex: 0x1C1C1B), location: 0.55),
                        .init(color: Color(hex: 0x050505), location: 1),
                    ],
                    center: UnitPoint(x: 0.36, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.5
                ))
                .frame(width: size * 0.68, height: size * 0.68)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
    }

    /// Stries du moletage : 30 dents claires et sombres.
    private static var knurl: Gradient {
        let teeth = 30
        var stops: [Gradient.Stop] = []
        for tooth in 0..<teeth {
            let start = Double(tooth) / Double(teeth)
            let middle = start + 0.5 / Double(teeth)
            let end = Double(tooth + 1) / Double(teeth)
            stops.append(.init(color: Color(hex: 0x0F0F0F), location: start))
            stops.append(.init(color: Color(hex: 0x0F0F0F), location: middle))
            stops.append(.init(color: Color(hex: 0x2B2B2B), location: middle))
            stops.append(.init(color: Color(hex: 0x2B2B2B), location: end))
        }
        return Gradient(stops: stops)
    }
}

/// Voyant rond : orange, vert ou éteint.
struct IndicatorLamp: View {
    enum Glow {
        case off
        case orange
        case green
    }

    let glow: Glow
    var size: CGFloat = 16

    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: colors,
                center: UnitPoint(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: size * 0.7
            ))
            .frame(width: size, height: size)
            .shadow(color: haloColor.opacity(glow == .off ? 0 : 0.9), radius: size * 0.35)
            .shadow(color: haloColor.opacity(glow == .off ? 0 : 0.5), radius: size * 0.8)
    }

    private var colors: [Color] {
        switch glow {
        case .off: [Color(hex: 0x6B4A33), Color(hex: 0x3A2211), Color(hex: 0x1C1008)]
        case .orange: [Color(hex: 0xFFE0B8), Palette.electricOrange, Color(hex: 0x7A2600)]
        case .green: [Color(hex: 0xE6FFD6), Palette.neonGreen, Color(hex: 0x136A02)]
        }
    }

    private var haloColor: Color {
        glow == .green ? Palette.neonGreen : Palette.electricOrange
    }
}

/// Halo elliptique, équivalent d'un `radial-gradient(Lpx Hpx at X Y, couleur, transparent 70 %)` CSS.
struct GlowSpot: View {
    let center: CGPoint
    let radii: CGSize
    let color: Color
    var fade: Double = 0.7

    var body: some View {
        EllipticalGradient(
            stops: [.init(color: color, location: 0), .init(color: color.opacity(0), location: fade)],
            center: .center,
            startRadiusFraction: 0,
            endRadiusFraction: 0.5
        )
        .frame(width: radii.width * 2, height: radii.height * 2)
        .placed(x: center.x - radii.width, y: center.y - radii.height)
    }
}

/// Bouton sans habillage système qui s'enfonce un peu quand on appuie.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
