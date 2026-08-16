import Foundation
import CryptoKit

enum ContentHasher {
    static func hash(data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    static func hash(text: String) -> String {
        hash(data: Data(text.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    }

    static func hash(file url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunk = 1024 * 1024
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: chunk)
            guard let data, !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }

    static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
