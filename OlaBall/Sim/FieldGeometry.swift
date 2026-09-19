import Foundation
import simd

/// World units are yards. x runs across the field (0 = middle), z runs down the field.
/// z = 0 is the offense's own goal line, z = 100 is the goal line they attack.
enum Field {
    static let width: Float = 53.3
    static let halfWidth: Float = width / 2
    static let endZoneDepth: Float = 10
    static let length: Float = 100
    static let hashX: Float = 3.1        // hash marks are ~6.2 yards apart
    static let uprightHalfWidth: Float = 3.1
    static let crossbarHeight: Float = 3.3
    static let uprightHeight: Float = 13

    static func isOutOfBounds(_ p: SIMD2<Float>) -> Bool { abs(p.x) > halfWidth }
}

/// A point on the turf.
typealias FieldPoint = SIMD2<Float>

extension SIMD2 where Scalar == Float {
    var length: Float { simd_length(self) }
    var normalized: SIMD2<Float> { let l = length; return l > 0.0001 ? self / l : .zero }
    func distance(to other: SIMD2<Float>) -> Float { simd_distance(self, other) }
}
