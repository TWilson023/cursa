import SwiftUI

struct OverlayView: View {
    var config: PresetConfiguration
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent scrim
            Color.black.opacity(0.08)

            // Path preview
            Canvas { context, size in
                drawPreview(context: context, size: size)
            }

            // Instructions
            if !config.hasPlacedCenter {
                VStack(spacing: 8) {
                    Text(instructionText)
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Press Escape to cancel")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleDrag(start: value.startLocation, current: value.location)
                }
                .onEnded { value in
                    handleDragEnd(start: value.startLocation, end: value.location)
                }
        )
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }

    private var instructionText: String {
        switch config.presetType {
        case .circle: "Click and drag to set center and radius"
        case .figure8: "Click and drag to set center and size"
        case .line: "Click and drag to set start and end points"
        }
    }

    // MARK: - Gesture Handling

    private func handleDrag(start: CGPoint, current: CGPoint) {
        config.isDragging = true
        config.hasPlacedCenter = true

        switch config.presetType {
        case .circle:
            config.center = start
            config.radius = max(10, distance(start, current))
        case .figure8:
            config.center = start
            config.size = max(10, distance(start, current))
        case .line:
            config.startPoint = start
            config.endPoint = current
        }
    }

    private func handleDragEnd(start: CGPoint, end: CGPoint) {
        config.isDragging = false
        handleDrag(start: start, current: end)
    }

    // MARK: - Preview Drawing

    private func drawPreview(context: GraphicsContext, size: CGSize) {
        guard config.hasPlacedCenter else { return }

        let strokeStyle = StrokeStyle(lineWidth: 2, dash: [8, 4])
        let color = Color.accentColor

        switch config.presetType {
        case .circle:
            let rect = CGRect(
                x: config.center.x - config.radius,
                y: config.center.y - config.radius,
                width: config.radius * 2,
                height: config.radius * 2
            )
            let circle = Path(ellipseIn: rect)
            context.stroke(circle, with: .color(color), style: strokeStyle)

            // Center dot
            let dotRect = CGRect(x: config.center.x - 4, y: config.center.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))

        case .figure8:
            var path = Path()
            let steps = 200
            for i in 0...steps {
                let t = Double(i) / Double(steps) * 2 * .pi
                let x = config.center.x + config.size * sin(t)
                let y = config.center.y + config.size * sin(t) * cos(t)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(color), style: strokeStyle)

            // Center dot
            let dotRect = CGRect(x: config.center.x - 4, y: config.center.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))

        case .line:
            var path = Path()
            path.move(to: config.startPoint)
            path.addLine(to: config.endPoint)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2))

            // Endpoint dots
            let startDot = CGRect(x: config.startPoint.x - 5, y: config.startPoint.y - 5, width: 10, height: 10)
            let endDot = CGRect(x: config.endPoint.x - 5, y: config.endPoint.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: startDot), with: .color(color))
            context.fill(Path(ellipseIn: endDot), with: .color(color.opacity(0.5)))
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
