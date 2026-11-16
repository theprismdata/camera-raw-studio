import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case korean
    case english
    case japanese
    case simplifiedChinese

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            localized("시스템 설정")
        case .korean:
            "한국어"
        case .english:
            "English"
        case .japanese:
            "日本語"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .korean:
            Locale(identifier: "ko")
        case .english:
            Locale(identifier: "en")
        case .japanese:
            Locale(identifier: "ja")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    fileprivate var localizationCode: String? {
        switch self {
        case .system:
            nil
        case .korean:
            "ko"
        case .english:
            "en"
        case .japanese:
            "ja"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }
}

func localized(_ key: String) -> String {
    let storedValue = UserDefaults.standard.string(forKey: "appLanguage")
    let language = storedValue.flatMap(AppLanguage.init(rawValue:)) ?? .system
    guard
        let code = language.localizationCode,
        let path = Bundle.main.path(forResource: code, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else {
        return NSLocalizedString(key, bundle: .main, comment: "")
    }
    return NSLocalizedString(key, bundle: bundle, comment: "")
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localized(key), locale: Locale.current, arguments: arguments)
}
