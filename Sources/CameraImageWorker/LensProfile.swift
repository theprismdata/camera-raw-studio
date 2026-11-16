import Foundation

struct LensProfile: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let focalLength: Double
    let aperture: Double
    let distortionCorrection: Double

    static let sony11mmF18 = LensProfile(
        id: "sony-e-11-f1.8",
        name: "Sony E 11mm F1.8",
        focalLength: 11,
        aperture: 1.8,
        distortionCorrection: 0.11
    )

    static let sony15mmF14 = LensProfile(
        id: "sony-e-15-f1.4-g",
        name: "Sony E 15mm F1.4 G",
        focalLength: 15,
        aperture: 1.4,
        distortionCorrection: 0.07
    )

    static let sony16to50 = LensProfile(
        id: "sony-e-pz-16-50",
        name: "Sony E PZ 16–50mm",
        focalLength: 16,
        aperture: 3.5,
        distortionCorrection: 0.09
    )

    static let presets: [LensProfile] = [sony11mmF18, sony15mmF14, sony16to50]

    static func custom(focalLength: Double, aperture: Double, correction: Double) -> LensProfile {
        LensProfile(
            id: "custom",
            name: "사용자 렌즈 \(focalLength.formatted())mm F\(aperture.formatted())",
            focalLength: focalLength,
            aperture: aperture,
            distortionCorrection: correction
        )
    }
}
