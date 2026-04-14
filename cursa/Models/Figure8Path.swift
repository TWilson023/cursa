import CoreGraphics

struct Figure8Path: MousePath {
    let center: CGPoint
    let size: Double
    let duration: Double
    let isLooping = true

    var points: [MousePoint] {
        let stepCount = max(Int(duration * 60), 60)
        return (0...stepCount).map { i in
            let t = Double(i) / Double(stepCount)
            let angle = t * 2 * .pi
            let x = center.x + size * sin(angle)
            let y = center.y + size * sin(angle) * cos(angle)
            return MousePoint(
                timestamp: t * duration,
                position: CGPoint(x: x, y: y)
            )
        }
    }

    static func defaultPath() -> Figure8Path {
        let mouseLocation = CGEvent(source: nil)?.location ?? CGPoint(x: 500, y: 500)
        return Figure8Path(center: mouseLocation, size: 100, duration: 4.0)
    }
}
