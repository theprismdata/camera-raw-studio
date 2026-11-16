import Foundation

enum EditApplicationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case allFiles
    case individual

    var id: Self { self }

    var title: String {
        switch self {
        case .allFiles:
            "모든 파일 자동 설정"
        case .individual:
            "개별 설정"
        }
    }
}

enum AIDenoiseStrength: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case low
    case medium
    case high

    var id: Self { self }

    var title: String {
        switch self {
        case .off:
            "사용 안 함"
        case .low:
            "약하게"
        case .medium:
            "보통"
        case .high:
            "강하게"
        }
    }

    var blendAmount: Float {
        switch self {
        case .off:
            0
        case .low:
            0.35
        case .medium:
            0.65
        case .high:
            1
        }
    }
}

enum ShakeCorrectionStrength: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case low
    case medium
    case high

    var id: Self { self }

    var title: String {
        switch self {
        case .off:
            "사용 안 함"
        case .low:
            "약하게"
        case .medium:
            "보통"
        case .high:
            "강하게"
        }
    }
}

enum FaceRestorationStrength: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case low
    case medium
    case high

    var id: Self { self }

    var title: String {
        switch self {
        case .off:
            "사용 안 함"
        case .low:
            "약하게"
        case .medium:
            "보통"
        case .high:
            "강하게"
        }
    }
}

struct NormalizedRegion: Hashable, Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum CropAspect: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case freeform
    case square
    case fourByThree
    case threeByTwo
    case sixteenByNine

    var id: Self { self }

    var title: String {
        switch self {
        case .original:
            "원본"
        case .freeform:
            "자유"
        case .square:
            "1:1"
        case .fourByThree:
            "4:3"
        case .threeByTwo:
            "3:2"
        case .sixteenByNine:
            "16:9"
        }
    }

    var ratio: Double? {
        switch self {
        case .original:
            nil
        case .freeform:
            nil
        case .square:
            1
        case .fourByThree:
            4.0 / 3.0
        case .threeByTwo:
            3.0 / 2.0
        case .sixteenByNine:
            16.0 / 9.0
        }
    }
}

struct DevelopSettings: Hashable, Codable, Sendable {
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let highlights: Double
    let shadows: Double
    let whites: Double
    let blacks: Double
    let vignetteAmount: Double
    let vignetteMidpoint: Double
    let vignetteFeather: Double
    let grainAmount: Double
    let grainSize: Double
    let grainRoughness: Double
    let perspectiveVertical: Double
    let perspectiveHorizontal: Double
    let whiteBalanceTemperatureShift: Double
    let whiteBalanceTint: Double
    let aiDenoiseStrength: AIDenoiseStrength
    let shakeCorrectionStrength: ShakeCorrectionStrength
    let faceRestorationStrength: FaceRestorationStrength
    let faceRegion: NormalizedRegion?
    let rotationDegrees: Double
    let cropAspect: CropAspect
    let cropCustomRatio: Double
    let cropZoom: Double
    let cropOffsetX: Double
    let cropOffsetY: Double
    let jpegQuality: Double
    let lens: LensProfile

    static let defaultSettings = DevelopSettings(
        exposure: 0,
        contrast: 1.05,
        saturation: 1,
        highlights: 0,
        shadows: 0,
        whites: 0,
        blacks: 0,
        vignetteAmount: 0,
        vignetteMidpoint: 0.5,
        vignetteFeather: 0.5,
        grainAmount: 0,
        grainSize: 1,
        grainRoughness: 0.5,
        perspectiveVertical: 0,
        perspectiveHorizontal: 0,
        whiteBalanceTemperatureShift: 0,
        whiteBalanceTint: 0,
        aiDenoiseStrength: .off,
        shakeCorrectionStrength: .off,
        faceRestorationStrength: .off,
        faceRegion: nil,
        rotationDegrees: 0,
        cropAspect: .original,
        cropCustomRatio: 1,
        cropZoom: 1,
        cropOffsetX: 0,
        cropOffsetY: 0,
        jpegQuality: 0.92,
        lens: .sony11mmF18
    )

    private enum CodingKeys: String, CodingKey {
        case exposure
        case contrast
        case saturation
        case highlights
        case shadows
        case whites
        case blacks
        case vignetteAmount
        case vignetteMidpoint
        case vignetteFeather
        case grainAmount
        case grainSize
        case grainRoughness
        case perspectiveVertical
        case perspectiveHorizontal
        case whiteBalanceTemperatureShift
        case whiteBalanceTint
        case aiDenoiseStrength
        case shakeCorrectionStrength
        case faceRestorationStrength
        case faceRegion
        case rotationDegrees
        case cropAspect
        case cropCustomRatio
        case cropZoom
        case cropOffsetX
        case cropOffsetY
        case jpegQuality
        case lens
    }

    init(
        exposure: Double,
        contrast: Double,
        saturation: Double,
        highlights: Double,
        shadows: Double,
        whites: Double,
        blacks: Double,
        vignetteAmount: Double,
        vignetteMidpoint: Double,
        vignetteFeather: Double,
        grainAmount: Double,
        grainSize: Double,
        grainRoughness: Double,
        perspectiveVertical: Double,
        perspectiveHorizontal: Double,
        whiteBalanceTemperatureShift: Double,
        whiteBalanceTint: Double,
        aiDenoiseStrength: AIDenoiseStrength,
        shakeCorrectionStrength: ShakeCorrectionStrength,
        faceRestorationStrength: FaceRestorationStrength,
        faceRegion: NormalizedRegion?,
        rotationDegrees: Double,
        cropAspect: CropAspect,
        cropCustomRatio: Double,
        cropZoom: Double,
        cropOffsetX: Double,
        cropOffsetY: Double,
        jpegQuality: Double,
        lens: LensProfile
    ) {
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.highlights = highlights
        self.shadows = shadows
        self.whites = whites
        self.blacks = blacks
        self.vignetteAmount = vignetteAmount
        self.vignetteMidpoint = vignetteMidpoint
        self.vignetteFeather = vignetteFeather
        self.grainAmount = grainAmount
        self.grainSize = grainSize
        self.grainRoughness = grainRoughness
        self.perspectiveVertical = perspectiveVertical
        self.perspectiveHorizontal = perspectiveHorizontal
        self.whiteBalanceTemperatureShift = whiteBalanceTemperatureShift
        self.whiteBalanceTint = whiteBalanceTint
        self.aiDenoiseStrength = aiDenoiseStrength
        self.shakeCorrectionStrength = shakeCorrectionStrength
        self.faceRestorationStrength = faceRestorationStrength
        self.faceRegion = faceRegion
        self.rotationDegrees = rotationDegrees
        self.cropAspect = cropAspect
        self.cropCustomRatio = cropCustomRatio
        self.cropZoom = cropZoom
        self.cropOffsetX = cropOffsetX
        self.cropOffsetY = cropOffsetY
        self.jpegQuality = jpegQuality
        self.lens = lens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try container.decode(Double.self, forKey: .exposure)
        contrast = try container.decode(Double.self, forKey: .contrast)
        saturation = try container.decode(Double.self, forKey: .saturation)
        highlights = try container.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        shadows = try container.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        whites = try container.decodeIfPresent(Double.self, forKey: .whites) ?? 0
        blacks = try container.decodeIfPresent(Double.self, forKey: .blacks) ?? 0
        vignetteAmount = try container.decodeIfPresent(Double.self, forKey: .vignetteAmount) ?? 0
        vignetteMidpoint = try container.decodeIfPresent(Double.self, forKey: .vignetteMidpoint) ?? 0.5
        vignetteFeather = try container.decodeIfPresent(Double.self, forKey: .vignetteFeather) ?? 0.5
        grainAmount = try container.decodeIfPresent(Double.self, forKey: .grainAmount) ?? 0
        grainSize = try container.decodeIfPresent(Double.self, forKey: .grainSize) ?? 1
        grainRoughness = try container.decodeIfPresent(Double.self, forKey: .grainRoughness) ?? 0.5
        perspectiveVertical = try container.decodeIfPresent(Double.self, forKey: .perspectiveVertical) ?? 0
        perspectiveHorizontal = try container.decodeIfPresent(Double.self, forKey: .perspectiveHorizontal) ?? 0
        whiteBalanceTemperatureShift = try container.decode(Double.self, forKey: .whiteBalanceTemperatureShift)
        whiteBalanceTint = try container.decode(Double.self, forKey: .whiteBalanceTint)
        aiDenoiseStrength = try container.decode(AIDenoiseStrength.self, forKey: .aiDenoiseStrength)
        shakeCorrectionStrength = try container.decodeIfPresent(
            ShakeCorrectionStrength.self,
            forKey: .shakeCorrectionStrength
        ) ?? .off
        faceRestorationStrength = try container.decodeIfPresent(
            FaceRestorationStrength.self,
            forKey: .faceRestorationStrength
        ) ?? .off
        faceRegion = try container.decodeIfPresent(NormalizedRegion.self, forKey: .faceRegion)
        rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
        cropAspect = try container.decodeIfPresent(CropAspect.self, forKey: .cropAspect) ?? .original
        cropCustomRatio = try container.decodeIfPresent(Double.self, forKey: .cropCustomRatio) ?? 1
        cropZoom = try container.decodeIfPresent(Double.self, forKey: .cropZoom) ?? 1
        cropOffsetX = try container.decodeIfPresent(Double.self, forKey: .cropOffsetX) ?? 0
        cropOffsetY = try container.decodeIfPresent(Double.self, forKey: .cropOffsetY) ?? 0
        jpegQuality = try container.decode(Double.self, forKey: .jpegQuality)
        lens = try container.decode(LensProfile.self, forKey: .lens)
    }
}

struct BatchItem: Identifiable, Sendable {
    enum State: Sendable {
        case waiting
        case processing
        case completed(URL)
        case failed(String)
    }

    let id: URL
    let source: URL
    var state: State = .waiting

    var displayName: String { source.lastPathComponent }
}
