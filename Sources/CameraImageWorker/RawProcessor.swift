import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UniformTypeIdentifiers

enum RawProcessorError: LocalizedError {
    case unreadableImage(URL)
    case jpegEncodingFailed(URL)
    case previewEncodingFailed(URL)

    var errorDescription: String? {
        switch self {
        case .unreadableImage(let url):
            "이미지를 읽을 수 없습니다: \(url.lastPathComponent)"
        case .jpegEncodingFailed(let url):
            "JPEG 변환에 실패했습니다: \(url.lastPathComponent)"
        case .previewEncodingFailed(let url):
            "미리보기를 만들 수 없습니다: \(url.lastPathComponent)"
        }
    }
}

actor RawProcessor {
    private let context = CIContext(options: [
        .cacheIntermediates: false,
        .useSoftwareRenderer: false
    ])
    private let denoiser = RestormerDenoiser()

    func develop(source: URL, destinationFolder: URL, settings: DevelopSettings) throws -> URL {
        try writeDeveloped(
            source: source,
            destinationURL: Self.outputURL(for: source, in: destinationFolder),
            settings: settings
        )
    }

    func saveEdited(source: URL, destinationFolder: URL, settings: DevelopSettings) throws -> URL {
        try writeDeveloped(
            source: source,
            destinationURL: Self.availableEditedOutputURL(for: source, in: destinationFolder),
            settings: settings
        )
    }

    private func writeDeveloped(
        source: URL,
        destinationURL: URL,
        settings: DevelopSettings
    ) throws -> URL {
        let image = try developedImage(source: source, settings: settings)
        let enhanced = try denoiser.enhance(
            image,
            strength: settings.aiDenoiseStrength,
            context: context
        )

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: settings.jpegQuality
        ]

        do {
            try context.writeJPEGRepresentation(
                of: enhanced,
                to: destinationURL,
                colorSpace: colorSpace,
                options: options
            )
        } catch {
            throw RawProcessorError.jpegEncodingFailed(source)
        }
        return destinationURL
    }

    func previewJPEGData(source: URL, settings: DevelopSettings, maxDimension: CGFloat = 1_600) throws -> Data {
        let image = try developedImage(source: source, settings: settings)
        let longestEdge = max(image.extent.width, image.extent.height)
        let previewLimit = settings.aiDenoiseStrength == .off ? maxDimension : min(maxDimension, 640)
        let scale = min(1, previewLimit / longestEdge)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let preview = try denoiser.enhance(
            scaled,
            strength: settings.aiDenoiseStrength,
            context: context
        )
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        guard let data = context.jpegRepresentation(
            of: preview,
            colorSpace: colorSpace,
            options: [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.82
            ]
        ) else {
            throw RawProcessorError.previewEncodingFailed(source)
        }
        return data
    }

    static func outputURL(for source: URL, in destinationFolder: URL) -> URL {
        destinationFolder
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("jpg")
    }

    static func availableEditedOutputURL(for source: URL, in destinationFolder: URL) -> URL {
        let stem = source.deletingPathExtension().lastPathComponent
        let firstChoice = destinationFolder
            .appendingPathComponent("\(stem)_edit")
            .appendingPathExtension("jpg")
        guard FileManager.default.fileExists(atPath: firstChoice.path) else { return firstChoice }

        var sequence = 2
        while true {
            let candidate = destinationFolder
                .appendingPathComponent("\(stem)_edit_\(sequence)")
                .appendingPathExtension("jpg")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            sequence += 1
        }
    }

    private func developedImage(source: URL, settings: DevelopSettings) throws -> CIImage {
        guard var image = sourceImage(source: source, settings: settings) else {
            throw RawProcessorError.unreadableImage(source)
        }

        image = applyLensCorrection(to: image, strength: settings.lens.distortionCorrection)
        image = applyStraightening(to: image, degrees: settings.rotationDegrees)
        return applyTone(to: image, settings: settings)
    }

    private func sourceImage(source: URL, settings: DevelopSettings) -> CIImage? {
        guard PhotoDiscovery.isRaw(source) else {
            return CIImage(contentsOf: source, options: [.applyOrientationProperty: true])
        }

        guard let rawFilter = CIRAWFilter(imageURL: source) else { return nil }
        rawFilter.neutralTemperature = Float(
            min(50_000, max(2_000, Double(rawFilter.neutralTemperature) + settings.whiteBalanceTemperatureShift))
        )
        rawFilter.neutralTint = Float(
            min(150, max(-150, Double(rawFilter.neutralTint) + settings.whiteBalanceTint))
        )
        return rawFilter.outputImage?.oriented(rawFilter.orientation)
    }

    private func applyTone(to image: CIImage, settings: DevelopSettings) -> CIImage {
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = image
        exposure.ev = Float(settings.exposure)

        let controls = CIFilter.colorControls()
        controls.inputImage = exposure.outputImage
        controls.contrast = Float(settings.contrast)
        controls.saturation = Float(settings.saturation)

        return controls.outputImage ?? image
    }

    private func applyLensCorrection(to image: CIImage, strength: Double) -> CIImage {
        guard abs(strength) > 0.001 else { return image }

        let filter = CIFilter.bumpDistortion()
        filter.inputImage = image.clampedToExtent()
        filter.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        filter.radius = Float(max(image.extent.width, image.extent.height) * 0.72)
        filter.scale = Float(-strength)
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    private func applyStraightening(to image: CIImage, degrees: Double) -> CIImage {
        guard abs(degrees) > 0.001 else { return image }

        let radians = degrees * .pi / 180
        let scale = Self.straighteningScale(
            width: image.extent.width,
            height: image.extent.height,
            radians: radians
        )
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: radians)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -center.x, y: -center.y)
        return image.transformed(by: transform).cropped(to: image.extent)
    }

    static func straighteningScale(width: CGFloat, height: CGFloat, radians: Double) -> CGFloat {
        let sine = abs(sin(radians))
        let cosine = abs(cos(radians))
        let horizontalCoverage = cosine + (height / width) * sine
        let verticalCoverage = cosine + (width / height) * sine
        return max(horizontalCoverage, verticalCoverage)
    }
}
