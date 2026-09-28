import SwiftUI

/// Anime une vue au rythme de l'affichage (30 images par seconde suffisent pour l'ambiance).
/// Avec « Réduire les animations » (Accessibilité), la vue reste figée.
struct Ambient<Content: View>: View {
    @ViewBuilder var content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                content(timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

/// Balancement de la lampe suspendue : ±3° en 7,6 s, la lumière suit.
enum LampSwing {
    static func angle(at time: Double) -> Double {
        3 * sin(2 * .pi * time / 7.6)
    }

    /// Décalage horizontal de la flaque de lumière pour un angle donné.
    static func lightOffset(at time: Double) -> CGFloat {
        CGFloat(-10 * angle(at: time))
    }
}

/// Bouffées qui montent en grossissant et s'effacent : vapeur du café, fumée de la cigarette.
struct RisingPuffs: View {
    struct Puff {
        let origin: CGPoint
        let diameter: CGFloat
        let alpha: Double
        let delay: Double
    }

    let puffs: [Puff]
    let period: Double
    let travel: CGSize
    let scales: ClosedRange<Double>
    let peakOpacity: Double
    /// Moment (entre 0 et 1) où la bouffée est la plus visible.
    let peakAt: Double
    var color = Color(red: 0.92, green: 0.91, blue: 0.88)
    var blur: CGFloat = 6
    /// Zone de dessin : les bouffées y restent, même en montant.
    let area: CGSize

    var body: some View {
        Ambient { time in
            ZStack(alignment: .topLeading) {
                ForEach(puffs.indices, id: \.self) { index in
                    puffView(puffs[index], time: time)
                }
            }
            .frame(width: area.width, height: area.height, alignment: .topLeading)
            .blur(radius: blur)
        }
        .allowsHitTesting(false)
    }

    private func puffView(_ puff: Puff, time: Double) -> some View {
        let phase = (time + period - puff.delay).truncatingRemainder(dividingBy: period) / period
        let eased = 1 - (1 - phase) * (1 - phase)
        let opacity = phase < peakAt
            ? peakOpacity * phase / peakAt
            : peakOpacity * (1 - (phase - peakAt) / (1 - peakAt))
        let scale = scales.lowerBound + (scales.upperBound - scales.lowerBound) * eased
        return Circle()
            .fill(color.opacity(puff.alpha))
            .frame(width: puff.diameter, height: puff.diameter)
            .scaleEffect(scale)
            .opacity(opacity)
            .placed(x: puff.origin.x + travel.width * eased, y: puff.origin.y + travel.height * eased)
    }
}
