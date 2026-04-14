import CoreGraphics
import Foundation

enum ClickType: Sendable {
    case leftDown, leftUp
    case rightDown, rightUp
    case otherDown, otherUp
}

struct ClickEvent: Sendable {
    let timestamp: TimeInterval
    let position: CGPoint
    let type: ClickType
}

struct MousePoint: Sendable {
    let timestamp: TimeInterval
    let position: CGPoint
}
