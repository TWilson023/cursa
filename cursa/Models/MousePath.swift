import CoreGraphics
import Foundation

protocol MousePath: Sendable {
    var points: [MousePoint] { get }
    var clicks: [ClickEvent] { get }
    var duration: TimeInterval { get }
    var isLooping: Bool { get }
}

extension MousePath {
    var clicks: [ClickEvent] { [] }
    var isLooping: Bool { true }
}
