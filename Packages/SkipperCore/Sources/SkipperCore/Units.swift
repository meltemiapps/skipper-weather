import Foundation

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case celsius, fahrenheit
    public var symbol: String { self == .celsius ? "°C" : "°F" }
}

public enum PressureUnit: String, CaseIterable, Codable, Sendable {
    case hectopascals, millibars, inchesOfMercury
    public var symbol: String {
        switch self {
        case .hectopascals: return "hPa"
        case .millibars: return "mb"
        case .inchesOfMercury: return "inHg"
        }
    }
}

public enum WindUnit: String, CaseIterable, Codable, Sendable {
    case knots, beaufort, kilometresPerHour, metresPerSecond, milesPerHour
    /// Symbol for numeric units. Beaufort is rendered by the UI as a localised "Force N".
    public var symbol: String {
        switch self {
        case .knots: return "kn"
        case .beaufort: return "Bft"
        case .kilometresPerHour: return "km/h"
        case .metresPerSecond: return "m/s"
        case .milesPerHour: return "mph"
        }
    }
}

public enum DistanceUnit: String, CaseIterable, Codable, Sendable {
    case nauticalMiles, kilometres, miles
    public var symbol: String {
        switch self {
        case .nauticalMiles: return "nm"
        case .kilometres: return "km"
        case .miles: return "mi"
        }
    }
}

public enum HeightUnit: String, CaseIterable, Codable, Sendable {
    case metres, feet
    public var symbol: String { self == .metres ? "m" : "ft" }
}

/// All conversions go through a canonical SI-or-marine base unit:
/// temperature °C, pressure hPa, wind knots, distance nautical miles, height metres.
public enum Convert {
    public static let metresPerNauticalMile = 1852.0
    public static let metresPerStatuteMile = 1609.344
    public static let metresPerFoot = 0.3048
    public static let hPaPerInHg = 33.8638866667

    // MARK: Temperature
    public static func temperature(fromCelsius c: Double, to unit: TemperatureUnit) -> Double {
        unit == .celsius ? c : c * 9.0 / 5.0 + 32.0
    }
    public static func temperatureToCelsius(_ value: Double, from unit: TemperatureUnit) -> Double {
        unit == .celsius ? value : (value - 32.0) * 5.0 / 9.0
    }

    // MARK: Pressure (1 hPa == 1 mb exactly)
    public static func pressure(fromHPa hPa: Double, to unit: PressureUnit) -> Double {
        unit == .inchesOfMercury ? hPa / hPaPerInHg : hPa
    }
    public static func pressureToHPa(_ value: Double, from unit: PressureUnit) -> Double {
        unit == .inchesOfMercury ? value * hPaPerInHg : value
    }

    // MARK: Wind
    public static func wind(fromKnots kn: Double, to unit: WindUnit) -> Double {
        switch unit {
        case .knots: return kn
        case .beaufort: return Double(Beaufort.force(knots: kn))
        case .kilometresPerHour: return kn * 1.852
        case .metresPerSecond: return kn * metresPerNauticalMile / 3600.0
        case .milesPerHour: return kn * metresPerNauticalMile / metresPerStatuteMile
        }
    }
    /// Beaufort input converts to the midpoint of that force's band.
    public static func windToKnots(_ value: Double, from unit: WindUnit) -> Double {
        switch unit {
        case .knots: return value
        case .beaufort: return Beaufort.midpointKnots(force: Int(value.rounded()))
        case .kilometresPerHour: return value / 1.852
        case .metresPerSecond: return value * 3600.0 / metresPerNauticalMile
        case .milesPerHour: return value * metresPerStatuteMile / metresPerNauticalMile
        }
    }

    // MARK: Distance
    public static func distance(fromNauticalMiles nm: Double, to unit: DistanceUnit) -> Double {
        switch unit {
        case .nauticalMiles: return nm
        case .kilometres: return nm * metresPerNauticalMile / 1000.0
        case .miles: return nm * metresPerNauticalMile / metresPerStatuteMile
        }
    }
    public static func distanceToNauticalMiles(_ value: Double, from unit: DistanceUnit) -> Double {
        switch unit {
        case .nauticalMiles: return value
        case .kilometres: return value * 1000.0 / metresPerNauticalMile
        case .miles: return value * metresPerStatuteMile / metresPerNauticalMile
        }
    }

    // MARK: Height
    public static func height(fromMetres m: Double, to unit: HeightUnit) -> Double {
        unit == .metres ? m : m / metresPerFoot
    }
    public static func heightToMetres(_ value: Double, from unit: HeightUnit) -> Double {
        unit == .metres ? value : value * metresPerFoot
    }
}

/// Sensible defaults: marine units for wind and distance everywhere,
/// imperial temperature/pressure/height only for US-measurement locales.
public struct UnitPreferences: Codable, Equatable, Sendable {
    public var temperature: TemperatureUnit
    public var pressure: PressureUnit
    public var wind: WindUnit
    public var distance: DistanceUnit
    public var height: HeightUnit

    public init(temperature: TemperatureUnit, pressure: PressureUnit, wind: WindUnit,
                distance: DistanceUnit, height: HeightUnit) {
        self.temperature = temperature
        self.pressure = pressure
        self.wind = wind
        self.distance = distance
        self.height = height
    }

    public static func defaults(usesUSMeasurement: Bool) -> UnitPreferences {
        UnitPreferences(
            temperature: usesUSMeasurement ? .fahrenheit : .celsius,
            pressure: usesUSMeasurement ? .inchesOfMercury : .hectopascals,
            wind: .knots,
            distance: .nauticalMiles,
            height: usesUSMeasurement ? .feet : .metres
        )
    }
}
