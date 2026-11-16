import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

final class FaceRestorer {
    func restore(
        _ image: CIImage,
        strength: FaceRestorationStrength,
        manualRegion: NormalizedRegion?,
        context: CIContext
    ) -> CIImage {
        guard strength != .off else { return image }
        guard let source = context.createCGImage(image, from: image.extent) else { return image }

        let faceRects: [CGRect]
        if let manualRegion {
            faceRects = [imageRect(for: manualRegion, extent: image.extent)]
        } else {
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: source, orientation: .up)
            guard
                (try? handler.perform([request])) != nil,
                let observations = request.results,
                !observations.isEmpty
            else { return image }
            faceRects = observations.map { imageRect(for: $0.boundingBox, extent: image.extent) }
        }

        let parameters: (noise: Float, sharpness: Float, contrast: Float)
        switch strength {
        case .off:
            return image
        case .low:
            parameters = (0.018, 0.22, 1.015)
        case .medium:
            parameters = (0.03, 0.38, 1.025)
        case .high:
            parameters = (0.045, 0.55, 1.04)
        }

        var result = image
        for faceRect in faceRects {
            let expandedRect = faceRect.insetBy(
                dx: -faceRect.width * 0.22,
                dy: -faceRect.height * 0.28
            ).intersection(image.extent)

            let noiseReduction = CIFilter.noiseReduction()
            noiseReduction.inputImage = result
            noiseReduction.noiseLevel = parameters.noise
            noiseReduction.sharpness = 0.4

            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = noiseReduction.outputImage
            sharpen.sharpness = parameters.sharpness

            let controls = CIFilter.colorControls()
            controls.inputImage = sharpen.outputImage
            controls.contrast = parameters.contrast
            controls.saturation = 1.01

            let gradient = CIFilter.radialGradient()
            gradient.center = CGPoint(x: expandedRect.midX, y: expandedRect.midY)
            gradient.radius0 = Float(min(expandedRect.width, expandedRect.height) * 0.32)
            gradient.radius1 = Float(max(expandedRect.width, expandedRect.height) * 0.68)
            gradient.color0 = CIColor.white
            gradient.color1 = CIColor.clear

            let blend = CIFilter.blendWithMask()
            blend.inputImage = controls.outputImage?.cropped(to: image.extent)
            blend.backgroundImage = result
            blend.maskImage = gradient.outputImage?.cropped(to: image.extent)
            result = blend.outputImage?.cropped(to: image.extent) ?? result
        }
        return result
    }

    private func imageRect(for normalizedRect: CGRect, extent: CGRect) -> CGRect {
        CGRect(
            x: extent.minX + normalizedRect.minX * extent.width,
            y: extent.minY + normalizedRect.minY * extent.height,
            width: normalizedRect.width * extent.width,
            height: normalizedRect.height * extent.height
        )
    }

    private func imageRect(for region: NormalizedRegion, extent: CGRect) -> CGRect {
        CGRect(
            x: extent.minX + CGFloat(region.x) * extent.width,
            y: extent.minY + CGFloat(1 - region.y - region.height) * extent.height,
            width: CGFloat(region.width) * extent.width,
            height: CGFloat(region.height) * extent.height
        )
    }
}
