//
//  ShareViewController.swift
//  Open in HTML Runner  (Share Extension)
//
//  This is the piece that makes "HTML Runner" show up when you tap Share in
//  Safari, Mail, Messages, Files, Notes… It grabs the HTML, hands it to the
//  app through the App Group container, then jumps straight into the app.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    // MARK: - UI

    private let card = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let openButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    private var capturedItems: [SharedHTMLItem] = []
    private var didAttemptAutoOpen = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        Task { await capture() }
    }

    // MARK: - Capture pipeline

    private func capture() async {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap { $0.attachments }
            .flatMap { $0 } ?? []

        guard !attachments.isEmpty else {
            finish(with: "Nothing to open", detail: "The shared item contained no readable content.")
            return
        }

        var results: [SharedHTMLItem] = []
        for provider in attachments {
            if let item = await load(from: provider) {
                results.append(item)
            }
        }

        guard !results.isEmpty else {
            finish(with: "Couldn't read that",
                   detail: "HTML Runner handles HTML, web pages, links and text. Images or video aren't supported.")
            return
        }

        // Remember and hand off to the app. Items go into the App Group
        // container when it exists; otherwise they travel inside the deep link.
        var storedCount = 0
        for item in results {
            if SharedStore.add(item) { storedCount += 1 }
        }
        capturedItems = results
        let viaURL = storedCount == 0 || !SharedStore.isSharingAvailable

        let first = results[0]
        let summary = first.isRemoteOnly
            ? (first.baseURLString ?? "")
            : "\(first.characterCount.formatted()) characters of HTML"

        DispatchQueue.main.async {
            if viaURL {
                self.statusLabel.text = "Opening HTML Runner…"
                self.detailLabel.text = results.count > 1
                    ? "\(results.count) items • handed over in the link"
                    : "\(first.title) • handed over in the link"
            } else {
                self.statusLabel.text = "Saved to your library"
                self.detailLabel.text = results.count > 1
                    ? "\(results.count) items • \(summary)"
                    : "\(first.title)\n\(summary)"
            }
            self.spinner.stopAnimating()
            self.openButton.isEnabled = true
            self.openButton.alpha = 1
            self.attemptAutoOpen(items: results, viaURL: viaURL)
        }
    }

    /// Converts one shared attachment into a `SharedHTMLItem`, trying the
    /// richest representation first: HTML file → web page URL → data URL →
    /// file → text.
    private func load(from provider: NSItemProvider) async -> SharedHTMLItem? {

        // 1. Real HTML (Safari "Share as Web Page", Files, Mail attachments…)
        if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier),
           let payload = try? await provider.loadItem(forTypeIdentifier: UTType.html.identifier) {
            if let html = string(from: payload) {
                let base = baseURL(from: payload)
                return SharedHTMLItem(title: HTMLTools.title(from: html),
                                      html: html,
                                      baseURLString: base?.absoluteString)
            }
        }

        // 2. A URL (page, data:, or a link to an .html file)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let payload = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
           let url = url(from: payload) {
            if url.scheme?.lowercased() == "data" {
                let html = Self.decodeDataURL(url) ?? url.absoluteString
                return SharedHTMLItem(title: HTMLTools.title(from: html),
                                      html: html, baseURLString: nil)
            }
            if url.isFileURL, let html = try? String(contentsOf: url, encoding: .utf8), HTMLTools.looksLikeHTML(html) {
                return SharedHTMLItem(title: HTMLTools.title(from: html),
                                      html: html,
                                      baseURLString: url.deletingLastPathComponent().absoluteString)
            }
            // Fetch a copy so the app can render it offline-ish; fall back to
            // the bare URL (the app loads it directly) if the fetch fails.
            if let html = await fetchHTML(from: url) {
                return SharedHTMLItem(title: HTMLTools.title(from: html),
                                      html: html,
                                      baseURLString: url.absoluteString)
            }
            return SharedHTMLItem(title: url.host ?? url.absoluteString,
                                  html: "",
                                  baseURLString: url.absoluteString)
        }

        // 3. A file on disk
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let payload = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
           let fileURL = url(from: payload),
           let html = try? String(contentsOf: fileURL, encoding: .utf8) {
            return SharedHTMLItem(title: HTMLTools.title(from: html),
                                  html: html,
                                  baseURLString: fileURL.deletingLastPathComponent().absoluteString)
        }

        // 4. Plain text — the common case (share a snippet from Messages,
        //    Notes, an editor, a chat AI reply, …)
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let payload = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
           let text = string(from: payload) {
            let html = HTMLTools.looksLikeHTML(text)
                ? text
                : "<pre class=\"plain\">\(HTMLTools.escape(text))</pre>"
            return SharedHTMLItem(title: HTMLTools.title(from: html, fallback: "Text snippet"),
                                  html: html,
                                  baseURLString: nil)
        }

        // 5. Raw data that claims to be HTML
        if let payload = try? await provider.loadItem(forTypeIdentifier: UTType.data.identifier),
           let data = payload as? Data,
           let html = String(data: data, encoding: .utf8),
           HTMLTools.looksLikeHTML(html) {
            return SharedHTMLItem(title: HTMLTools.title(from: html),
                                  html: html, baseURLString: nil)
        }

        return nil
    }

    // MARK: - Payload helpers

    private func string(from payload: NSSecureCoding?) -> String? {
        switch payload {
        case let text as String: return text
        case let attributed as NSAttributedString: return attributed.string
        case let data as Data: return String(data: data, encoding: .utf8)
        case let url as URL: return try? String(contentsOf: url, encoding: .utf8)
        default: return nil
        }
    }

    private func baseURL(from payload: NSSecureCoding?) -> URL? {
        if let url = payload as? URL, !url.isFileURL { return url }
        if let url = payload as? URL { return url.deletingLastPathComponent() }
        return nil
    }

    private func url(from payload: NSSecureCoding?) -> URL? {
        switch payload {
        case let url as URL: return url
        case let string as String: return URL(string: string)
        case let data as Data: return String(data: data, encoding: .utf8).flatMap(URL.init(string:))
        default: return nil
        }
    }

    /// Decodes `data:text/html;base64,…` and `data:text/html,<h1>hi</h1>` URLs.
    static func decodeDataURL(_ url: URL) -> String? {
        let absolute = url.absoluteString
        guard let commaIndex = absolute.firstIndex(of: ",") else { return nil }
        let meta = absolute[absolute.index(absolute.startIndex, offsetBy: 5)..<commaIndex]
        let payload = String(absolute[absolute.index(after: commaIndex)...])
        if meta.lowercased().contains("base64") {
            guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return payload.removingPercentEncoding
    }

    private func fetchHTML(from url: URL) async -> String? {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Hand-off to the app

    /// Launches the containing app. Share extensions can't use
    /// `UIApplication.shared`, so we walk the responder chain — the standard,
    /// well-known approach for this. If it is ever refused, the item is already
    /// in your library, so opening the app normally shows it at the top.
    @discardableResult
    private func openContainingApp(url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return true
            }
            responder = current.next
        }
        return false
    }

    private func attemptAutoOpen(items: [SharedHTMLItem], viaURL: Bool) {
        guard !didAttemptAutoOpen else { return }
        didAttemptAutoOpen = true
        let url: URL
        if viaURL, let payloadURL = SharedStore.importURL(for: items) {
            url = payloadURL
        } else if let byID = URL(string: "\(SharedStore.urlScheme)://open?id=\(items[0].id.uuidString)") {
            url = byID
        } else {
            url = URL(string: "\(SharedStore.urlScheme)://open")!
        }
        // Small delay so the hand-off write lands before the app wakes up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if !self.openContainingApp(url: url) {
                // Blocked (rare) → leave the sheet up with a clear next step.
                self.detailLabel.text = (self.detailLabel.text ?? "") +
                    "\nOpen HTML Runner from your Home Screen to view it."
            }
        }
    }

    // MARK: - Actions

    @objc private func openTapped() {
        let fallbackID = capturedItems.first?.id.uuidString ?? UUID().uuidString
        let url = SharedStore.importURL(for: capturedItems)
            ?? URL(string: "\(SharedStore.urlScheme)://open?id=\(fallbackID)")!
        if !openContainingApp(url: url) {
            statusLabel.text = "Open HTML Runner from the Home Screen"
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func doneTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func finish(with title: String, detail: String) {
        DispatchQueue.main.async {
            self.spinner.stopAnimating()
            self.titleLabel.text = title
            self.statusLabel.text = "Nothing saved"
            self.detailLabel.text = detail
            self.openButton.isHidden = true
        }
    }

    // MARK: - UI construction (programmatic, no storyboard)

    private func buildUI() {
        view.backgroundColor = .systemBackground

        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
        iconView.tintColor = .white
        iconView.backgroundColor = UIColor(red: 0.13, green: 0.42, blue: 0.98, alpha: 1)
        iconView.contentMode = .center
        iconView.layer.cornerRadius = 26
        iconView.layer.cornerCurve = .continuous
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "HTML Runner"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Reading shared HTML…"
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .secondaryLabel

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.numberOfLines = 5
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .tertiaryLabel
        detailLabel.textAlignment = .center

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        var config = UIButton.Configuration.filled()
        config.title = "Open in HTML Runner"
        config.cornerStyle = .large
        config.baseBackgroundColor = UIColor(red: 0.13, green: 0.42, blue: 0.98, alpha: 1)
        openButton.configuration = config
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.isEnabled = false
        openButton.alpha = 0.55
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        var doneConfig = UIButton.Configuration.plain()
        doneConfig.title = "Done"
        doneButton.configuration = doneConfig
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [iconView, titleLabel])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .center

        let stack = UIStackView(arrangedSubviews: [header, statusLabel, spinner, detailLabel, openButton, doneButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.setCustomSpacing(6, after: header)
        stack.setCustomSpacing(10, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            iconView.widthAnchor.constraint(equalToConstant: 52),
            iconView.heightAnchor.constraint(equalToConstant: 52),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            openButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }
}
