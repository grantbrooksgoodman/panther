//
//  GIFImageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/09/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI
import WebKit

/* Proprietary */
import AppSubsystem

public struct GIFImage: UIViewRepresentable {
    // MARK: - Dependencies

    @Dependency(\.mainBundle) private var mainBundle: Bundle

    // MARK: - Properties

    /// Whether the GIF is currently visible.
    ///
    /// The web view is kept primed – its markup loaded and the GIF's bytes prepared – even while
    /// hidden, so it appears instantly rather than cold-starting. Playback is withheld until the
    /// view becomes visible, though, so the animation always begins from its first frame the
    /// moment this transitions from `false` to `true`, rather than entering mid-loop.
    private let isActive: Bool

    private let name: String

    // MARK: - Init

    public init(
        _ name: String,
        isActive: Bool = true
    ) {
        self.name = name
        self.isActive = isActive
    }

    // MARK: - Make Coordinator

    public func makeCoordinator() -> Coordinator {
        .init()
    }

    // MARK: - Make UIView

    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Render transparently so the artwork – not an opaque
        // document background – is all that shows.
        webView.isOpaque = false
        webView.backgroundColor = .clear

        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInset = .zero
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.isUserInteractionEnabled = false

        context.coordinator.wasActive = isActive
        loadImage(into: webView)

        // Begin playback from the first frame once the primed load
        // finishes, for a view that is created already visible.
        if isActive {
            context.coordinator.requestRestart(of: webView)
        }

        return webView
    }

    // MARK: - Load Image

    /// Loads the GIF into a controlled HTML wrapper.
    ///
    /// Loading the raw GIF data would let WebKit synthesize an image document whose user-agent
    /// styling – body margins, shrink-to-fit scaling, centering – can't be controlled. Wrapping
    /// the image in explicit markup makes it fill the web view exactly, matching a native
    /// `Image` drawn with `resizable()` into the same frame.
    ///
    /// The markup also defines `restartGif()`, which the coordinator invokes to play the
    /// animation from its first frame. WebKit shares a single playback timeline across every
    /// element that references the same image URL, so cloning the element or reassigning the
    /// same source resumes the animation mid-loop rather than restarting it. Each play therefore
    /// mints a fresh object URL over the in-memory GIF bytes and swaps in a new element backed by
    /// it – a distinct URL WebKit animates from the first frame, with no network round-trip.
    ///
    /// At load the markup only decodes the GIF's bytes, leaving the image element empty; it never
    /// starts the animation. Playback is deferred to the first `restartGif()` the coordinator
    /// fires when the view becomes visible, so priming never leaves a stale, mid-loop frame on
    /// screen to flash before the animation resets.
    private func loadImage(into webView: WKWebView) {
        guard let url = mainBundle.url(
            forResource: name,
            withExtension: "gif"
        ) else { return }

        do {
            let data = try Data(contentsOf: url)
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
            html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; }
            img { width: 100%; height: 100%; object-fit: fill; display: block; }
            </style>
            </head>
            <body>
            <img id="gif">
            <script>
            var GIF_BASE64 = "\(data.base64EncodedString())";
            var GIF_BYTES = null;

            function gifBytes() {
                if (!GIF_BYTES) {
                    var binary = atob(GIF_BASE64);
                    GIF_BYTES = new Uint8Array(binary.length);
                    for (var i = 0; i < binary.length; i++) {
                        GIF_BYTES[i] = binary.charCodeAt(i);
                    }
                }
                return GIF_BYTES;
            }

            function freshObjectURL() {
                return URL.createObjectURL(new Blob([gifBytes()], { type: 'image/gif' }));
            }

            function restartGif() {
                var current = document.getElementById('gif');
                var fresh = document.createElement('img');
                fresh.id = 'gif';
                if (current && current.parentNode) {
                    current.removeAttribute('id');
                    current.parentNode.replaceChild(fresh, current);
                    if (current.src && current.src.indexOf('blob:') === 0) {
                        URL.revokeObjectURL(current.src);
                    }
                } else {
                    document.body.appendChild(fresh);
                }
                fresh.src = freshObjectURL();
            }

            // Prime the decode without starting playback; the coordinator
            // plays the animation from its first frame once the view is visible.
            gifBytes();
            </script>
            </body>
            </html>
            """

            webView.loadHTMLString(html, baseURL: nil)
        } catch {
            Logger.log(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    // MARK: - Update UIView

    public func updateUIView(
        _ uiView: WKWebView,
        context: Context
    ) {
        let coordinator = context.coordinator
        defer { coordinator.wasActive = isActive }

        // Begin (or restart) playback from the first frame on the hidden →
        // visible transition. While hidden the GIF is primed but never plays,
        // so it always enters from its first frame rather than mid-loop.
        guard isActive,
              !coordinator.wasActive else { return }

        coordinator.requestRestart(of: uiView)
    }
}
