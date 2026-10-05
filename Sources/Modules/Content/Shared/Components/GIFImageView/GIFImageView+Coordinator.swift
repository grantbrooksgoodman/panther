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

/* Proprietary */
import AppSubsystem

public extension GIFImage {
    /// The object that drives the primed web view's animation playback.
    final class Coordinator: NSObject, WKNavigationDelegate {
        // MARK: - Properties

        var wasActive = false

        private var appearanceChangeTask: Task<Void, Never>?
        private var hasPendingRestart = false
        private var isDarkModeActive = false
        private var isLoaded = false
        @SharedEvent(\.traitCollectionChanged) private var traitCollectionChanged

        // MARK: - Object Lifecycle

        deinit {
            appearanceChangeTask?.cancel()
        }

        // MARK: - WKNavigationDelegate Conformance

        public func webView(
            _ webView: WKWebView,
            didFinish _: WKNavigation!
        ) {
            isLoaded = true
            applyTheme(to: webView)
            guard hasPendingRestart else { return }
            hasPendingRestart = false
            restart(webView)
        }

        // MARK: - Methods

        /// Re-applies the tint on trait collection changes, if not already observing.
        func observeAppearanceChanges(of webView: WKWebView) {
            guard appearanceChangeTask == nil else { return }
            appearanceChangeTask = Task { [weak self, weak webView] in
                guard let traitCollectionChanges = self?.traitCollectionChanged.events else { return }
                for await _ in traitCollectionChanges {
                    guard let self,
                          let webView else { return }

                    updateTheme(
                        isDarkModeActive: ThemeService.isDarkModeActive,
                        in: webView
                    )
                }
            }
        }

        /// Restarts the animation, deferring until the primed load finishes if it hasn't yet.
        func requestRestart(of webView: WKWebView) {
            guard isLoaded else {
                hasPendingRestart = true
                return
            }

            restart(webView)
        }

        /// Keeps the latest theme ready while loading, then updates the tint without restarting playback.
        func updateTheme(
            isDarkModeActive: Bool,
            in webView: WKWebView
        ) {
            guard self.isDarkModeActive != isDarkModeActive else { return }
            self.isDarkModeActive = isDarkModeActive

            guard isLoaded else { return }
            applyTheme(to: webView)
        }

        private func applyTheme(to webView: WKWebView) {
            let filter = isDarkModeActive ? "brightness(0) invert(1)" : "none"
            webView.evaluateJavaScript(
                """
                document.documentElement.style.setProperty('--gif-filter', '\(filter)');
                """
            )
        }

        private func restart(_ webView: WKWebView) {
            webView.evaluateJavaScript("restartGif();")
        }
    }
}
