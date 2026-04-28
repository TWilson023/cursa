import CoreGraphics
import Foundation

protocol MousePath: Sendable {
    var points: [MousePoint] { get }
    var duration: TimeInterval { get }
}
