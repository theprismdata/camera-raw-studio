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

struct DevelopSettings: Hashable, Codable, Sendable {
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let whiteBalanceTemperatureShift: Double
    let whiteBalanceTint: Double
    let aiDenoiseStrength: AIDenoiseStrength
    let rotationDegrees: Double
    let jpegQuality: Double
    let lens: LensProfile

    static let defaultSettings = DevelopSettings(
        exposure: 0,
        contrast: 1.05,
        saturation: 1,
        whiteBalanceTemperatureShift: 0,
        whiteBalanceTint: 0,
        aiDenoiseStrength: .off,
        rotationDegrees: 0,
        jpegQuality: 0.92,
        lens: .sony11mmF18
    )
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
