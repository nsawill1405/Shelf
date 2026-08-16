import Foundation

/// Copies imported binaries into Shelf's own Application Support container so
/// they remain available long after the originating drag session ends.
enum ItemStorage {

    static var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Shelf", isDirectory: true)
                       .appendingPathComponent("Storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copies a file into storage under a unique name, preserving its extension.
    @discardableResult
    static func copyIn(_ source: URL) throws -> URL {
        let ext = source.pathExtension
        let filename = "\(UUID().uuidString)\(ext.isEmpty ? "" : ".\(ext)")"
        let destination = storageDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Writes raw data into storage with the given extension.
    @discardableResult
    static func write(_ data: Data, extension ext: String) throws -> URL {
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = storageDirectory.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    static func removeFile(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)
    }

    /// Total on-disk footprint of copied content, in bytes.
    static var usageBytes: Int64 {
        let enumerator = FileManager.default.enumerator(
            at: storageDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var total: Int64 = 0
        while let url = enumerator?.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    static var formattedUsage: String {
        ByteCountFormatter.string(fromByteCount: usageBytes, countStyle: .file)
    }
}
