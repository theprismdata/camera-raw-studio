import CoreImage
import CoreML
import Foundation

enum RestormerDenoiserError: LocalizedError {
    case modelMissing
    case imageRenderingFailed
    case predictionOutputMissing
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            localized("Restormer 로컬 AI 모델을 찾을 수 없습니다.")
        case .imageRenderingFailed:
            localized("AI 노이즈 제거용 이미지를 만들 수 없습니다.")
        case .predictionOutputMissing:
            localized("Restormer 모델의 출력 형식이 올바르지 않습니다.")
        case .imageCreationFailed:
            localized("AI 노이즈 제거 결과 이미지를 만들 수 없습니다.")
        }
    }
}

final class RestormerDenoiser {
    private static let patchSize = 256
    private static let border = 16
    private static let contentSize = patchSize - border * 2
    private static let planeSize = patchSize * patchSize

    private var cachedModel: MLModel?

    func enhance(
        _ image: CIImage,
        strength: AIDenoiseStrength,
        context: CIContext
    ) throws -> CIImage {
        guard strength != .off else { return image }
        guard let source = context.createCGImage(image, from: image.extent) else {
            throw RestormerDenoiserError.imageRenderingFailed
        }

        let width = source.width
        let height = source.height
        var sourcePixels = [UInt8](repeating: 0, count: width * height * 4)
        try draw(source, into: &sourcePixels, width: width, height: height)
        var resultPixels = sourcePixels
        let model = try loadModel()

        for originY in stride(from: 0, to: height, by: Self.contentSize) {
            for originX in stride(from: 0, to: width, by: Self.contentSize) {
                try processPatch(
                    originX: originX,
                    originY: originY,
                    width: width,
                    height: height,
                    source: sourcePixels,
                    result: &resultPixels,
                    blendAmount: strength.blendAmount,
                    model: model
                )
            }
        }

        guard let result = makeImage(pixels: &resultPixels, width: width, height: height) else {
            throw RestormerDenoiserError.imageCreationFailed
        }
        return CIImage(cgImage: result)
    }

    private func loadModel() throws -> MLModel {
        if let cachedModel { return cachedModel }
        guard let modelURL = Bundle.main.url(
            forResource: "RestormerRealDenoising",
            withExtension: "mlmodelc"
        ) else {
            throw RestormerDenoiserError.modelMissing
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let model = try MLModel(contentsOf: modelURL, configuration: configuration)
        cachedModel = model
        return model
    }

    private func processPatch(
        originX: Int,
        originY: Int,
        width: Int,
        height: Int,
        source: [UInt8],
        result: inout [UInt8],
        blendAmount: Float,
        model: MLModel
    ) throws {
        let input = try MLMultiArray(
            shape: [1, 3, NSNumber(value: Self.patchSize), NSNumber(value: Self.patchSize)],
            dataType: .float32
        )
        let inputValues = input.dataPointer.bindMemory(
            to: Float.self,
            capacity: Self.planeSize * 3
        )

        for patchY in 0..<Self.patchSize {
            let sourceY = min(height - 1, max(0, originY + patchY - Self.border))
            for patchX in 0..<Self.patchSize {
                let sourceX = min(width - 1, max(0, originX + patchX - Self.border))
                let sourceIndex = (sourceY * width + sourceX) * 4
                let tensorIndex = patchY * Self.patchSize + patchX
                inputValues[tensorIndex] = Float(source[sourceIndex]) / 255
                inputValues[Self.planeSize + tensorIndex] = Float(source[sourceIndex + 1]) / 255
                inputValues[Self.planeSize * 2 + tensorIndex] = Float(source[sourceIndex + 2]) / 255
            }
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: ["inp_img": input])
        let prediction = try model.prediction(from: provider)
        guard
            let outputName = model.modelDescription.outputDescriptionsByName.keys.first,
            let output = prediction.featureValue(for: outputName)?.multiArrayValue
        else {
            throw RestormerDenoiserError.predictionOutputMissing
        }
        let copyWidth = min(Self.contentSize, width - originX)
        let copyHeight = min(Self.contentSize, height - originY)

        switch output.dataType {
        case .float16:
            let values = output.dataPointer.bindMemory(to: Float16.self, capacity: Self.planeSize * 3)
            copyOutput(
                values: values,
                copyWidth: copyWidth,
                copyHeight: copyHeight,
                originX: originX,
                originY: originY,
                width: width,
                source: source,
                result: &result,
                blendAmount: blendAmount
            )
        case .float32:
            let values = output.dataPointer.bindMemory(to: Float.self, capacity: Self.planeSize * 3)
            copyOutput(
                values: values,
                copyWidth: copyWidth,
                copyHeight: copyHeight,
                originX: originX,
                originY: originY,
                width: width,
                source: source,
                result: &result,
                blendAmount: blendAmount
            )
        case .double:
            let values = output.dataPointer.bindMemory(to: Double.self, capacity: Self.planeSize * 3)
            copyOutput(
                values: values,
                copyWidth: copyWidth,
                copyHeight: copyHeight,
                originX: originX,
                originY: originY,
                width: width,
                source: source,
                result: &result,
                blendAmount: blendAmount
            )
        default:
            throw RestormerDenoiserError.predictionOutputMissing
        }
    }

    private func copyOutput<Value: BinaryFloatingPoint>(
        values: UnsafeMutablePointer<Value>,
        copyWidth: Int,
        copyHeight: Int,
        originX: Int,
        originY: Int,
        width: Int,
        source: [UInt8],
        result: inout [UInt8],
        blendAmount: Float
    ) {
        for localY in 0..<copyHeight {
            for localX in 0..<copyWidth {
                let patchIndex = (localY + Self.border) * Self.patchSize + localX + Self.border
                let resultIndex = ((originY + localY) * width + originX + localX) * 4
                for channel in 0..<3 {
                    let original = Float(source[resultIndex + channel])
                    let restored = min(
                        1,
                        max(0, Float(values[channel * Self.planeSize + patchIndex]))
                    ) * 255
                    let blended = original + (restored - original) * blendAmount
                    result[resultIndex + channel] = UInt8(min(255, max(0, blended)).rounded())
                }
                result[resultIndex + 3] = 255
            }
        }
    }

    private func draw(
        _ image: CGImage,
        into pixels: inout [UInt8],
        width: Int,
        height: Int
    ) throws {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let drewImage = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewImage else { throw RestormerDenoiserError.imageRenderingFailed }
    }

    private func makeImage(pixels: inout [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }
            return context.makeImage()
        }
    }
}
