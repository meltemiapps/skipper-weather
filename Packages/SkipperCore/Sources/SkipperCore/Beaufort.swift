import Foundation

/// WMO Beaufort scale. Bands are in knots (10 m mean wind); probable wave
/// heights are the WMO open-sea reference values in metres.
public enum Beaufort {
    public struct Band: Equatable, Sendable {
        public let force: Int
        /// Inclusive lower bound in whole knots.
        public let lowerKnots: Int
        /// Inclusive upper bound in whole knots; nil for force 12.
        public let upperKnots: Int?
        public let probableWaveMetres: Double
        /// Localisation key for the descriptive name, e.g. "beaufort.6".
        public var nameKey: String { "beaufort.\(force)" }
    }

    public static let bands: [Band] = [
        Band(force: 0, lowerKnots: 0, upperKnots: 0, probableWaveMetres: 0),
        Band(force: 1, lowerKnots: 1, upperKnots: 3, probableWaveMetres: 0.1),
        Band(force: 2, lowerKnots: 4, upperKnots: 6, probableWaveMetres: 0.2),
        Band(force: 3, lowerKnots: 7, upperKnots: 10, probableWaveMetres: 0.6),
        Band(force: 4, lowerKnots: 11, upperKnots: 16, probableWaveMetres: 1.0),
        Band(force: 5, lowerKnots: 17, upperKnots: 21, probableWaveMetres: 2.0),
        Band(force: 6, lowerKnots: 22, upperKnots: 27, probableWaveMetres: 3.0),
        Band(force: 7, lowerKnots: 28, upperKnots: 33, probableWaveMetres: 4.0),
        Band(force: 8, lowerKnots: 34, upperKnots: 40, probableWaveMetres: 5.5),
        Band(force: 9, lowerKnots: 41, upperKnots: 47, probableWaveMetres: 7.0),
        Band(force: 10, lowerKnots: 48, upperKnots: 55, probableWaveMetres: 9.0),
        Band(force: 11, lowerKnots: 56, upperKnots: 63, probableWaveMetres: 11.5),
        Band(force: 12, lowerKnots: 64, upperKnots: nil, probableWaveMetres: 14.0)
    ]

    /// Force for a wind speed in knots. Speeds are rounded to the nearest knot first.
    public static func force(knots: Double) -> Int {
        guard knots.isFinite, knots > 0 else { return 0 }
        let k = Int(knots.rounded())
        return bands.last(where: { k >= $0.lowerKnots })?.force ?? 0
    }

    public static func band(force: Int) -> Band {
        bands[min(max(force, 0), 12)]
    }

    public static func midpointKnots(force: Int) -> Double {
        let b = band(force: force)
        guard let upper = b.upperKnots else { return Double(b.lowerKnots) }
        return Double(b.lowerKnots + upper) / 2.0
    }
}

/// Barometric tendency over three hours, using the standard marine descriptors.
public enum PressureTendency: String, CaseIterable, Sendable {
    case steady
    case risingSlowly, rising, risingQuickly, risingVeryRapidly
    case fallingSlowly, falling, fallingQuickly, fallingVeryRapidly

    public var key: String { "tendency.\(rawValue)" }

    /// - Parameter change: pressure change in hPa over the preceding 3 hours.
    public static func classify(changeOver3h change: Double) -> PressureTendency {
        let a = abs(change)
        let rising = change > 0
        switch a {
        case ..<0.1: return .steady
        case ..<1.6: return rising ? .risingSlowly : .fallingSlowly
        case ..<3.6: return rising ? .rising : .falling
        case ...6.0: return rising ? .risingQuickly : .fallingQuickly
        default: return rising ? .risingVeryRapidly : .fallingVeryRapidly
        }
    }
}
