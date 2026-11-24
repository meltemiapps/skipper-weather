import Foundation

/// Every piece of text drawn inside a diagram. Each content file must translate all of them.
public enum DiagramLabel: String, CaseIterable, Sendable {
    case low, high, warmFront, coldFront, occludedFront, warmSector, coldAir, warmAir
    case trough, ridge, col, isobars, observer
    case cirrus, cirrostratus, altostratus, nimbostratus, cumulus, cumulonimbus, stratus
    case rain, showers, drizzle, squall, gustFront, anvil, downdraught, updraught
    case geostrophic, overSea, overLand, friction, pressureGradient, coriolis
    case backToWind, lowOnLeft
    case seaBreeze, landBreeze, katabatic, anabatic, day, night, land, sea, coldSea, warmSea
    case funnelling, convergence, divergence, strongerWind, lighterWind
    case meltemi, bora, mistral, sirocco
    case radiationFog, advectionFog, frontalFog, airTemperature, dewPoint, seaTemperature, saturation
    case windWithTide, windAgainstTide, tide, wind, swell, windWaves, fetch, wavelength, waveHeight
    case falling, rising, steady, hours, hPa
    case stable, unstable, parcel
    case calm, knots, halfBarb, fullBarb, pennant
    case force
    case polarMaritime, tropicalMaritime, polarContinental, tropicalContinental
    case highCloud, mediumCloud, lowCloud, height, inversion
    case visFog, visPoor, visModerate, visGood
    case issued, imminent, soon, later
    case departure, destination, refuge, front
    case gridPoint, modelWind, gusts
    case heaveTo, backedHeadsail, helmToWindward
    case lighterAround, strongerAround, passesNorth, passesSouth
}
