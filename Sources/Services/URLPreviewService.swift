import Foundation
import AppKit

/// Fetches a page title and favicon on-device. Page bytes are not stored.
enum URLPreviewService {
    static func enqueue(for item: ShelfItem) {
        let raw = item.sourceURL ?? item.contentText ?? ""
        guard item.type == .url, let url = absoluteURL(from: raw) else { return }
        let identifier = item.persistentModelID
        Task.detached(priority: .utility) {
            let preview = await fetch(url: url)
            await MainActor.run {
                let context = DataController.shared.context
                guard let model = context.model(for: identifier) as? ShelfItem else { return }
                if let title = preview.title, !title.isEmpty {
                    model.pageTitle = title
                    if model.title == raw || model.title == url.absoluteString || model.title.hasPrefix("http") {
                        model.title = title
                    }
                    let search = [model.searchableText, title].compactMap { $0 }.joined(separator: "\n")
                    model.searchableText = search
                }
                if let icon = preview.faviconPath {
                    model.faviconPath = icon
                }
                try? context.save()
            }
        }
    }

    private static func absoluteURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

    private struct Preview {
        var title: String?
        var faviconPath: String?
    }

    private static func fetch(url: URL) async -> Preview {
        var preview = Preview()
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Shelf/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return preview }

        preview.title = extractTitle(from: html)

        let iconURL = faviconURL(in: html, base: url)
        if let iconURL,
           let (iconData, response) = try? await URLSession.shared.data(from: iconURL),
           !iconData.isEmpty {
            let ext = (response.url?.pathExtension.isEmpty == false ? response.url!.pathExtension : "png")
            if let stored = try? ItemStorage.write(iconData, extension: ext) {
                preview.faviconPath = stored.path
            }
        }
        return preview
    }

    private static func extractTitle(from html: String) -> String? {
        let patterns = [
            "<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<title[^>]*>([^<]+)</title>"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let title = String(html[range])
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { return decodeHTML(title) }
            }
        }
        return nil
    }

    private static func faviconURL(in html: String, base: URL) -> URL? {
        let pattern = "<link[^>]+rel=[\"'][^\"']*icon[^\"']*[\"'][^>]+href=[\"']([^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            let href = String(html[range])
            if let url = URL(string: href, relativeTo: base)?.absoluteURL { return url }
        }
        return URL(string: "/favicon.ico", relativeTo: base)?.absoluteURL
    }

    private static func decodeHTML(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let parsed = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        return parsed?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? string
    }
}
