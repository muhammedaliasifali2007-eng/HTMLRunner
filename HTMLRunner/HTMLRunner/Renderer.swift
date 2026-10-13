//
//  HTMLRenderer.swift
//  HTML Runner
//
//  A WKWebView wrapper that renders arbitrary HTML. Remote content is loaded
//  with `loadHTMLString(_:baseURL:)`, which is scoped to that document and
//  never gets read access to local files — see README for the security notes.
//

import SwiftUI
import UIKit
import WebKit

struct HTMLRenderer: UIViewRepresentable {

    let item: SharedHTMLItem

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if #available(iOS 16.4, *) {
            webView.isInspectable = true   // Safari Web Inspector while debugging
        }
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedID != item.id else { return }
        context.coordinator.loadedID = item.id
        context.coordinator.load(item: item, in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var loadedID: UUID?

        func load(item: SharedHTMLItem, in webView: WKWebView) {
            if item.isRemoteOnly {
                if let url = item.baseURL {
                    webView.load(URLRequest(url: url))
                } else {
                    webView.loadHTMLString(HTMLTools.placeholderDocument, baseURL: nil)
                }
                return
            }
            let document = HTMLTools.document(from: item.html, baseURL: item.baseURL)
            webView.loadHTMLString(document, baseURL: item.baseURL)
        }

        /// Keep normal http(s) navigation inside the web view; hand exotic
        /// schemes (mailto:, tel:, other apps) to the system.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let scheme = url.scheme?.lowercased() ?? "about"
            if ["http", "https", "file", "data", "about", "blob"].contains(scheme) {
                decisionHandler(.allow)
            } else {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            }
        }
    }
}
