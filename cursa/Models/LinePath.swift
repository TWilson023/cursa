import CoreGraphics

struct LinePath: MousePath {
    let start: CGPoint
    let end: CGPoint
    let duration: Double
    let isLooping = true

    var points: [MousePoint] {
        let stepCount = max(Int(duration * 60), 60)
        return (0...stepCount).map { i in
            let t = Double(i) / Double(stepCount)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            return MousePoint(
                timestamp: t * duration,
                position: CGPoint(x: x, y: y)
            )
        }
    }

    static func defaultPath() -> LinePath {
        let mouseLocation = CGEvent(source: nil)?.location ?? CGPoint(x: 500, y: 500)
        return LinePath(
            start: CGPoint(x: mouseLocation.x - 100, y: mouseLocation.y),
            end: CGPoint(x: mouseLocation.x + 100, y: mouseLocation.y),
            duration: 2.0
        )
    }
}
