import Foundation

struct SavedEditDocument: Hashable, Codable, Sendable {
    let version: Int
    let editMode: EditApplicationMode
    let globalSettings: DevelopSettings
    let settingsByRelativePath: [String: DevelopSettings]
    let selectedRelativePaths: Set<String>
    let previewedRelativePath: String?

    init(
        editMode: EditApplicationMode,
        globalSettings: DevelopSettings,
        settingsByRelativePath: [String: DevelopSettings],
        selectedRelativePaths: Set<String>,
        previewedRelativePath: String?
    ) {
        version = 1
        self.editMode = editMode
        self.globalSettings = globalSettings
        self.settingsByRelativePath = settingsByRelativePath
        self.selectedRelativePaths = selectedRelativePaths
        self.previewedRelativePath = previewedRelativePath
    }
}

enum EditStore {
    static let fileName = ".sony-raw-studio-edits.json"

    static func save(_ document: SavedEditDocument, in folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(
            to: folder.appendingPathComponent(fileName),
            options: .atomic
        )
    }

    static func load(from folder: URL) throws -> SavedEditDocument? {
        let url = folder.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(SavedEditDocument.self, from: Data(contentsOf: url))
    }

    static func relativePath(for file: URL, in folder: URL) -> String? {
        let folderComponents = folder.standardizedFileURL.pathComponents
        let fileComponents = file.standardizedFileURL.pathComponents
        guard fileComponents.starts(with: folderComponents) else { return nil }
        return fileComponents.dropFirst(folderComponents.count).joined(separator: "/")
    }
}

struct AutoSaveRequest: Hashable, Sendable {
    let folder: URL
    let document: SavedEditDocument
}
