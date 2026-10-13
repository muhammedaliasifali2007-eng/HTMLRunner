//
//  SharedHTMLItem.swift
//  HTML Runner
//
//  The model that travels from the Share Extension into the app, plus the
//  small helpers used to detect / normalise HTML. This file is compiled into
//  BOTH targets (app + share extension).
//

import Foundation

// MARK: - Model

struct SharedHTMLItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()

    /// Best-effort human readable name (`<title>`, first heading, first text…).
    var title: String

    /// The raw HTML / text that was shared. May be empty when `baseURLString`
    /// is set – in that case the app simply loads the URL in the web view.
    var html: String

    /// Where relative links & assets should resolve from (page URL, or the
    /// "origin app" of a `data:` URL share).
    var baseURLString: String?

    /// Name of the app the content was shared from, when iOS tells us.
    var sourceApp: String?

    var date: Date = Date()

    var baseURL: URL? {
        guard let baseURLString, !baseURLString.isEmpty else { return nil }
        return URL(string: baseURLString)
    }

    /// True when we only have a URL and no local HTML copy.
    var isRemoteOnly: Bool { html.isEmpty && baseURL != nil }

    var characterCount: Int { html.count }

    /// A short, tag-stripped teaser used in the list UI.
    var previewText: String {
        if isRemoteOnly { return baseURLString ?? "" }
        let stripped = HTMLTools.stripTags(html)
        return stripped.isEmpty ? "Empty document" : stripped
    }
}

// MARK: - HTML helpers

enum HTMLTools {

    /// Cheap "is this actually HTML?" test used when a share arrives as plain text.
    static func looksLikeHTML(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2, trimmed.contains("<"), trimmed.contains(">") else { return false }
        let pattern = "<[a-zA-Z!/?][^>]*>"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /// True when the share already looks like a complete document.
    static func isFullDocument(_ string: String) -> Bool {
        let lower = string.lowercased()
        return lower.contains("<html") || lower.contains("<!doctype")
    }

    /// Pulls a nice title out of the markup.
    static func title(from html: String, fallback: String = "Untitled HTML") -> String {
        let lower = html.lowercased()

        for tag in ["title", "h1", "h2"] {
            if let openRange = lower.range(of: "<\(tag)"),
               let closeOfOpen = lower[openRange.lowerBound...].firstIndex(of: ">"),
               let closeRange = lower.range(of: "</\(tag)", range: closeOfOpen..<lower.endIndex) {
                let start = lower.index(after: closeOfOpen)
                let raw = String(html[start..<closeRange.lowerBound])
                let cleaned = stripTags(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    return String(cleaned.prefix(70))
                }
            }
        }

        let stripped = stripTags(html).trimmingCharacters(in: .whitespacesAndNewlines)
        if !stripped.isEmpty {
            let firstLine = stripped.split(separator: "\n").first.map(String.init) ?? stripped
            let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return String(cleaned.prefix(70)) }
        }
        return fallback
    }

    /// Removes tags + decodes the handful of entities that matter for previews.
    static func stripTags(_ html: String) -> String {
        var text = html
        // Drop <script>/<style> bodies entirely.
        for tag in ["script", "style"] {
            while let open = text.range(of: "<\(tag)", options: [.caseInsensitive]),
                  let close = text.range(of: "</\(tag)>", options: [.caseInsensitive],
                                         range: open.upperBound..<text.endIndex) {
                text.removeSubrange(open.lowerBound..<close.upperBound)
            }
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        // Collapse whitespace runs so list rows stay tidy.
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{2,}", with: "\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Escapes text that is about to be dropped inside a `<pre>` block.
    static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Wraps fragments (and plain text) in a full, mobile-friendly document so
    /// they render correctly instead of as unstyled soup.
    static func document(from raw: String, baseURL: URL? = nil) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return placeholderDocument }

        if isFullDocument(trimmed) { return raw }

        if !looksLikeHTML(trimmed) {
            // Plain text share → show it as pre-formatted text.
            return wrap("""
            <pre class="plain">\(escape(trimmed))</pre>
            """)
        }
        return wrap(trimmed)
    }

    /// A friendly "nothing to show" page.
    static var placeholderDocument: String {
        wrap("""
        <div class="empty">
          <h1>Nothing to render</h1>
          <p>This entry has no HTML stored locally. If it was a URL, tap the Safari button to open it.</p>
        </div>
        """)
    }

    /// The shared shell used for wrapped fragments: sets the viewport, a
    /// system font, dark-mode support and safe-area padding.
    private static func wrap(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
          :root { color-scheme: light dark; }
          body {
            margin: 0;
            padding: 16px calc(16px + env(safe-area-inset-left)) calc(24px + env(safe-area-inset-bottom)) calc(16px + env(safe-area-inset-right));
            font: -apple-system-body, -apple-system, system-ui, sans-serif;
            font-size: 17px;
            line-height: 1.5;
            color: #111;
            background: #fff;
            -webkit-text-size-adjust: 100%;
            overflow-wrap: break-word;
          }
          @media (prefers-color-scheme: dark) {
            body { color: #eee; background: #111; }
            a { color: #6cf; }
          }
          img, video, svg, iframe, table { max-width: 100%; height: auto; }
          pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 14px; }
          pre { white-space: pre-wrap; word-break: break-word; background: rgba(127,127,127,.12); padding: 12px; border-radius: 10px; }
          .empty { text-align: center; color: #888; margin-top: 15vh; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}
