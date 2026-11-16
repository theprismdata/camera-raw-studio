import Foundation
import ImageIO

struct PhotoMetadata: Hashable, Sendable {
    let camera: String?
    let lens: String?
    let focalLength: String?
    let aperture: String?
    let shutterSpeed: String?
    let iso: String?
    let dimensions: String?
    let capturedAt: String?

    var summaryItems: [String] {
        [camera, lens, focalLength, aperture, shutterSpeed, iso, dimensions, capturedAt]
            .compactMap { $0 }
    }

    static func load(from url: URL) -> PhotoMetadata? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let camera = [
            tiff[kCGImagePropertyTIFFMake] as? String,
            tiff[kCGImagePropertyTIFFModel] as? String
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        let lens = exif[kCGImagePropertyExifLensModel] as? String
        let focalValue = number(exif[kCGImagePropertyExifFocalLength])
        let apertureValue = number(exif[kCGImagePropertyExifFNumber])
        let exposureValue = number(exif[kCGImagePropertyExifExposureTime])
        let isoValues = exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber]
        let width = number(properties[kCGImagePropertyPixelWidth])?.intValue
        let height = number(properties[kCGImagePropertyPixelHeight])?.intValue
        let capturedAt = exif[kCGImagePropertyExifDateTimeOriginal] as? String

        return PhotoMetadata(
            camera: camera.isEmpty ? nil : camera,
            lens: lens,
            focalLength: focalValue.map { "\($0.doubleValue.formatted(.number.precision(.fractionLength(0...1))))mm" },
            aperture: apertureValue.map { "F\($0.doubleValue.formatted(.number.precision(.fractionLength(1))))" },
            shutterSpeed: exposureValue.map { exposureLabel($0.doubleValue) },
            iso: isoValues?.first.map { "ISO \($0.intValue)" },
            dimensions: width.flatMap { width in height.map { "\(width)×\($0)" } },
            capturedAt: capturedAt
        )
    }

    private static func number(_ value: Any?) -> NSNumber? {
        value as? NSNumber
    }

    private static func exposureLabel(_ seconds: Double) -> String {
        if seconds >= 1 {
            return "\(seconds.formatted(.number.precision(.fractionLength(1))))s"
        }
        guard seconds > 0 else { return "0s" }
        return "1/\((1 / seconds).rounded().formatted(.number.precision(.fractionLength(0))))s"
    }
}
