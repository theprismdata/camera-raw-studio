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
            localizedFormat("이미지를 읽을 수 없습니다: %@", url.lastPathComponent)
        case .jpegEncodingFailed(let url):
            localizedFormat("JPEG 변환에 실패했습니다: %@", url.lastPathComponent)
        case .previewEncodingFailed(let url):
            localizedFormat("미리보기를 만들 수 없습니다: %@", url.lastPathComponent)
        }
    }
}

actor RawProcessor {
    private let context = CIContext(options: [
        .cacheIntermediates: false,
        .useSoftwareRenderer: false
    ])
    private let denoiser = RestormerDenoiser()
    private let faceRestorer = FaceRestorer()

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
        let denoised = try denoiser.enhance(
            image,
            strength: settings.aiDenoiseStrength,
            context: context
        )
        let stabilized = applyShakeCorrection(
            to: denoised,
            strength: settings.shakeCorrectionStrength
        )
        let enhanced = faceRestorer.restore(
            stabilized,
            strength: settings.faceRestorationStrength,
            manualRegion: settings.faceRegion,
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
        let image = try developedImage(source: source, settings: settings, applyingCrop: false)
        let longestEdge = max(image.extent.width, image.extent.height)
        let previewLimit = settings.aiDenoiseStrength == .off ? maxDimension : min(maxDimension, 640)
        let scale = min(1, previewLimit / longestEdge)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let denoised = try denoiser.enhance(
            scaled,
            strength: settings.aiDenoiseStrength,
            context: context
        )
        let stabilized = applyShakeCorrection(
            to: denoised,
            strength: settings.shakeCorrectionStrength
        )
        let preview = faceRestorer.restore(
            stabilized,
            strength: settings.faceRestorationStrength,
            manualRegion: settings.faceRegion,
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

    private func developedImage(
        source: URL,
        settings: DevelopSettings,
        applyingCrop: Bool = true
    ) throws -> CIImage {
        guard var image = sourceImage(source: source, settings: settings) else {
            throw RawProcessorError.unreadableImage(source)
        }

        image = applyLensCorrection(to: image, strength: settings.lens.distortionCorrection)
        image = applyStraightening(to: image, degrees: settings.rotationDegrees)
        image = applyPerspective(to: image, settings: settings)
        if applyingCrop {
            image = Self.applyCrop(
                to: image,
                aspect: settings.cropAspect,
                customRatio: settings.cropCustomRatio,
                zoom: settings.cropZoom,
                offsetX: settings.cropOffsetX,
                offsetY: settings.cropOffsetY
            )
        }
        image = applyTone(to: image, settings: settings)
        image = applyVignette(to: image, settings: settings)
        return applyGrain(to: image, settings: settings)
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

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = controls.outputImage
        highlightShadow.highlightAmount = Float(min(2, max(0, 1 + settings.highlights)))
        highlightShadow.shadowAmount = Float(min(1, max(-1, settings.shadows)))

        let curve = CIFilter.toneCurve()
        curve.inputImage = highlightShadow.outputImage
        curve.point0 = CGPoint(x: 0, y: min(0.18, max(0, settings.blacks * 0.15)))
        curve.point1 = CGPoint(x: 0.25, y: min(0.45, max(0.05, 0.25 + settings.blacks * 0.12)))
        curve.point2 = CGPoint(x: 0.5, y: 0.5)
        curve.point3 = CGPoint(x: 0.75, y: min(0.95, max(0.55, 0.75 + settings.whites * 0.12)))
        curve.point4 = CGPoint(x: 1, y: min(1, max(0.82, 1 + min(0, settings.whites) * 0.15)))

        return curve.outputImage ?? highlightShadow.outputImage ?? controls.outputImage ?? image
    }

    private func applyShakeCorrection(
        to image: CIImage,
        strength: ShakeCorrectionStrength
    ) -> CIImage {
        guard strength != .off else { return image }

        let parameters: (radius: Float, intensity: Float, sharpness: Float)
        switch strength {
        case .off:
            return image
        case .low:
            parameters = (1.2, 0.35, 0.25)
        case .medium:
            parameters = (1.8, 0.55, 0.4)
        case .high:
            parameters = (2.4, 0.75, 0.55)
        }

        let unsharp = CIFilter.unsharpMask()
        unsharp.inputImage = image
        unsharp.radius = parameters.radius
        unsharp.intensity = parameters.intensity

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = unsharp.outputImage
        sharpen.sharpness = parameters.sharpness
        return (sharpen.outputImage ?? unsharp.outputImage ?? image).cropped(to: image.extent)
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

    private func applyPerspective(to image: CIImage, settings: DevelopSettings) -> CIImage {
        let vertical = settings.perspectiveVertical
        let horizontal = settings.perspectiveHorizontal
        guard abs(vertical) > 0.001 || abs(horizontal) > 0.001 else { return image }

        let extent = image.extent
        let verticalInset = extent.width * CGFloat(vertical) * 0.18
        let horizontalInset = extent.height * CGFloat(horizontal) * 0.18
        let filter = CIFilter.perspectiveTransform()
        filter.inputImage = image.clampedToExtent()
        filter.topLeft = CGPoint(
            x: extent.minX + verticalInset,
            y: extent.maxY - horizontalInset
        )
        filter.topRight = CGPoint(
            x: extent.maxX - verticalInset,
            y: extent.maxY + horizontalInset
        )
        filter.bottomLeft = CGPoint(
            x: extent.minX - verticalInset,
            y: extent.minY + horizontalInset
        )
        filter.bottomRight = CGPoint(
            x: extent.maxX + verticalInset,
            y: extent.minY - horizontalInset
        )
        return (filter.outputImage ?? image).cropped(to: extent)
    }

    private func applyVignette(to image: CIImage, settings: DevelopSettings) -> CIImage {
        guard abs(settings.vignetteAmount) > 0.001 else { return image }
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = Float(settings.vignetteAmount * 2)
        let baseRadius = min(image.extent.width, image.extent.height)
        filter.radius = Float(baseRadius * (0.18 + settings.vignetteMidpoint * 0.58 + settings.vignetteFeather * 0.18))
        return (filter.outputImage ?? image).cropped(to: image.extent)
    }

    private func applyGrain(to image: CIImage, settings: DevelopSettings) -> CIImage {
        guard settings.grainAmount > 0.001 else { return image }
        guard let random = CIFilter.randomGenerator().outputImage else { return image }
        let scale = CGFloat(max(0.35, settings.grainSize))
        let noise = random.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let monochrome = CIFilter.colorControls()
        monochrome.inputImage = noise
        monochrome.saturation = 0
        monochrome.contrast = Float(0.8 + settings.grainRoughness * 1.8)

        let amount = Float(settings.grainAmount * 0.12)
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = monochrome.outputImage
        matrix.rVector = CIVector(x: CGFloat(amount), y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: CGFloat(amount), z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: CGFloat(amount), w: 0)
        matrix.biasVector = CIVector(x: -CGFloat(amount) / 2, y: -CGFloat(amount) / 2, z: -CGFloat(amount) / 2, w: 0)

        let composite = CIFilter.additionCompositing()
        composite.inputImage = matrix.outputImage?.cropped(to: image.extent)
        composite.backgroundImage = image
        return (composite.outputImage ?? image).cropped(to: image.extent)
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

    static func cropRect(
        in extent: CGRect,
        aspect: CropAspect,
        customRatio: Double = 1,
        zoom: Double,
        offsetX: Double,
        offsetY: Double
    ) -> CGRect {
        let sourceRatio = extent.width / extent.height
        let targetRatio: CGFloat
        switch aspect {
        case .original:
            targetRatio = sourceRatio
        case .freeform:
            targetRatio = CGFloat(max(0.05, customRatio))
        default:
            targetRatio = CGFloat(aspect.ratio ?? Double(sourceRatio))
        }
        var width = extent.width
        var height = extent.height

        if sourceRatio > targetRatio {
            width = height * targetRatio
        } else {
            height = width / targetRatio
        }

        let safeZoom = CGFloat(min(10, max(1, zoom)))
        width /= safeZoom
        height /= safeZoom
        let horizontalTravel = max(0, extent.width - width) / 2
        let verticalTravel = max(0, extent.height - height) / 2
        let centerX = extent.midX + horizontalTravel * CGFloat(min(1, max(-1, offsetX)))
        let centerY = extent.midY - verticalTravel * CGFloat(min(1, max(-1, offsetY)))

        return CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        ).integral
    }

    private static func applyCrop(
        to image: CIImage,
        aspect: CropAspect,
        customRatio: Double,
        zoom: Double,
        offsetX: Double,
        offsetY: Double
    ) -> CIImage {
        let rect = cropRect(
            in: image.extent,
            aspect: aspect,
            customRatio: customRatio,
            zoom: zoom,
            offsetX: offsetX,
            offsetY: offsetY
        )
        return image.cropped(to: rect).transformed(
            by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY)
        )
    }
}
