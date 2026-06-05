import Foundation

/// A numeric constraint with optional tolerance or bounds.
/// Supports three modes (any combination):
/// - `value` alone: exact equality required
/// - `value` + `tolerance`: |actual - value| <= tolerance
/// - `min` and/or `max`: actual must lie within bounds
struct Tolerance: Codable, Hashable {
    var value: Double?
    var tolerance: Double?
    var min: Double?
    var max: Double?

    enum Verdict: Equatable {
        case pass
        case fail(reason: String)
    }

    func evaluate(_ actual: Double, label: String = "value") -> Verdict {
        if let value, let tolerance {
            return abs(actual - value) <= tolerance
                ? .pass
                : .fail(reason: "\(label) = \(actual) hors de \(value) ± \(tolerance)")
        }
        if let value, tolerance == nil, min == nil, max == nil {
            return actual == value
                ? .pass
                : .fail(reason: "\(label) = \(actual), attendu \(value)")
        }
        if let min, actual < min {
            return .fail(reason: "\(label) = \(actual) < min \(min)")
        }
        if let max, actual > max {
            return .fail(reason: "\(label) = \(actual) > max \(max)")
        }
        return .pass
    }

    /// Human-readable description of the constraint.
    var displayString: String {
        if let value, let tolerance { return "\(format(value)) ± \(format(tolerance))" }
        if let value { return format(value) }
        switch (min, max) {
        case let (lo?, hi?): return "[\(format(lo)) ; \(format(hi))]"
        case let (lo?, nil): return "≥ \(format(lo))"
        case let (nil, hi?): return "≤ \(format(hi))"
        default: return "—"
        }
    }

    private func format(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}

/// Rational frame rate (e.g. 25/1, 24000/1001).
/// Always compare rationals as rationals — never as Double.
struct RationalRate: Codable, Hashable {
    var num: Int
    var den: Int

    var asDouble: Double { Double(num) / Double(den) }

    var displayString: String {
        if den == 1 { return "\(num)" }
        let d = asDouble
        return String(format: "%.3f", d)
    }

    func equals(_ other: RationalRate) -> Bool {
        num * other.den == other.num * den
    }
}
