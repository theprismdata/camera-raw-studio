import Foundation

enum PhotoDiscovery {
    static let rawExtensions: Set<String> = ["arw", "raw", "dng"]
    static let supportedExtensions = rawExtensions.union(["jpg", "jpeg"])

    static func isRaw(_ url: URL) -> Bool {
        rawExtensions.contains(url.pathExtension.lowercased())
    }

    static func files(in folder: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var photos: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true, values.isHidden != true else { continue }
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            photos.append(url)
        }
        return photos.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }
}
