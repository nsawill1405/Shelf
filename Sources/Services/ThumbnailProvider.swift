import AppKit
import QuickLookThumbnailing

/// Generates file/PDF thumbnails using the system Quick Look generator.
enum ThumbnailProvider {

    static func thumbnail(for url: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            DispatchQueue.main.async {
                completion(representation?.nsImage)
            }
        }
    }
}
