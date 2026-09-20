//
//  GIFImageView+Coordinator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/09/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import WebKit

public extension GIFImage {
    /// The object that drives the primed web view's animation playback.
    final class Coordinator: NSObject, WKNavigationDelegate {
        // MARK: - Properties

        var wasActive = false

        private var hasPendingRestart = false
        private var isLoaded = false

        // MARK: - WKNavigationDelegate Conformance

        public func webView(
            _ webView: WKWebView,
            didFinish _: WKNavigation!
        ) {
            isLoaded = true
            guard hasPendingRestart else { return }
            hasPendingRestart = false
            restart(webView)
        }

        // MARK: - Methods

        /// Restarts the animation, deferring until the primed load finishes if it hasn't yet.
        func requestRestart(of webView: WKWebView) {
            guard isLoaded else {
                hasPendingRestart = true
                return
            }

            restart(webView)
        }

        private func restart(_ webView: WKWebView) {
            webView.evaluateJavaScript("restartGif();")
        }
    }
}
