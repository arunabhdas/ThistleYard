import Foundation

public struct Vector2: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static let zero = Vector2(x: 0, y: 0)
    public var length: Double { hypot(x, y) }
    public var normalized: Vector2 {
        guard isFinite else { return .zero }
        let scale = max(abs(x), abs(y))
        guard scale > 1e-12 else { return .zero }
        let scaled = Vector2(x: x / scale, y: y / scale)
        return scaled * (1 / scaled.length)
    }
    public func distance(to other: Vector2) -> Double { (self - other).length }
    public static func + (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    public static func - (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    public static func * (lhs: Self, rhs: Double) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
    public static func * (lhs: Double, rhs: Self) -> Self { rhs * lhs }
    var isFinite: Bool { x.isFinite && y.isFinite }
    func dot(_ other: Self) -> Double { x * other.x + y * other.y }
    func cross(_ other: Self) -> Double { x * other.y - y * other.x }
}
