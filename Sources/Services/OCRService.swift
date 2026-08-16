import Foundation
import AppKit
import Vision

/// On-device OCR using Apple's Vision framework. Results are stored in the
/// item's search metadata so screenshots become findable later.
enum OCRService {

    /// Kicks off OCR for a newly imported image; updates the item on the main actor.
    static func enqueue(imageFileAt url: URL, for item: ShelfItem) {
        let identifier = item.persistentModelID
        Task.detached(priority: .utility) {
            let text = await recognizeText(imageFileAt: url)
            guard !text.isEmpty else { return }
            await MainActor.run {
                let context = DataController.shared.context
                guard let model = context.model(for: identifier) as? ShelfItem else { return }
                let existing = model.searchableText ?? ""
                model.searchableText = existing.isEmpty ? text : existing + "\n" + text
                try? context.save()
            }
        }
    }

    static func recognizeText(imageFileAt url: URL) async -> String {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        return await recognizeText(cgImage: cgImage)
    }

    static func recognizeText(cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}
