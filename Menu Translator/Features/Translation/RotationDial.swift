import SwiftUI

/// Horizontal ruler for straightening the photo, modeled on the Photos app: drag the ticks
/// left or right under a fixed center line. One tick per degree, brighter every 10°.
struct RotationDial: View {
    /// Rotation in degrees.
    @Binding var degrees: Double

    @State private var dragStart: Double?

    private let range: ClosedRange<Double> = -45...45
    private let tickSpacing: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let midY = size.height / 2

            for tick in Int(range.lowerBound)...Int(range.upperBound) {
                let x = centerX + (Double(tick) - degrees) * tickSpacing
                guard x >= 0, x <= size.width else { continue }
                let isMajor = tick % 10 == 0
                var line = Path()
                line.move(to: CGPoint(x: x, y: midY - 8))
                line.addLine(to: CGPoint(x: x, y: midY + 8))
                context.stroke(line, with: .color(Colors.white.opacity(isMajor ? 1 : 0.4)), lineWidth: 1)
            }

            var indicator = Path()
            indicator.move(to: CGPoint(x: centerX, y: midY - 16))
            indicator.addLine(to: CGPoint(x: centerX, y: midY + 16))
            context.stroke(indicator, with: .color(Colors.white), lineWidth: 1.5)
        }
        .frame(height: 60)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.2),
                    .init(color: .black, location: 0.8),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = dragStart ?? degrees
                    dragStart = start
                    let newValue = start - value.translation.width / tickSpacing
                    degrees = min(max(newValue, range.lowerBound), range.upperBound)
                }
                .onEnded { _ in
                    dragStart = nil
                }
        )
        .sensoryFeedback(.selection, trigger: Int(degrees.rounded()))
        .accessibilityElement()
        .accessibilityLabel("Rotation")
        .accessibilityValue("\(Int(degrees.rounded())) degrees")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: degrees = min(degrees + 1, range.upperBound)
            case .decrement: degrees = max(degrees - 1, range.lowerBound)
            @unknown default: break
            }
        }.background(Colors.black)
    }
}

#Preview {
    @Previewable @State var degrees = 0.0
    RotationDial(degrees: $degrees)
}
