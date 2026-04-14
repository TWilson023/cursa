import CoreGraphics
import Foundation

@Observable
final class PresetConfiguration {
    var presetType: PresetType = .circle
    var center: CGPoint = .zero
    var radius: Double = 100
    var size: Double = 100
    var startPoint: CGPoint = .zero
    var endPoint: CGPoint = .zero
    var speed: Double = 3.0
    var isDragging: Bool = false
    var hasPlacedCenter: Bool = false

    func defaultSpeed(for preset: PresetType) -> Double {
        switch preset {
        case .circle: 3.0
        case .figure8: 4.0
        case .line: 2.0
        }
    }

    func reset(for preset: PresetType) {
        presetType = preset
        center = .zero
        radius = 100
        size = 100
        startPoint = .zero
        endPoint = .zero
        speed = defaultSpeed(for: preset)
        isDragging = false
        hasPlacedCenter = false
    }
}
