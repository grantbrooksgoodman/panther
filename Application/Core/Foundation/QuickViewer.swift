//
//  QuickViewer.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import QuickLook

/* 3rd-party */
import CoreArchitecture

public final class QuickViewer: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    // MARK: - Types

    private final class PreviewItem: NSObject, QLPreviewItem {
        // MARK: - Properties

        public var previewItemTitle: String?
        public var previewItemURL: URL?

        // MARK: - Init

        public init(
            title: String? = nil,
            url: URL? = nil
        ) {
            previewItemTitle = title
            previewItemURL = url
        }
    }

    // MARK: - Properties

    private var filePath = ""
    private var previewItemTitle: String?
    private var _onDismiss: (() -> Void)?

    // MARK: - Preview

    public func preview(
        fileAtPath path: String,
        title: String? = nil,
        embedded: Bool = false
    ) {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI

        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self

        filePath = path
        previewItemTitle = title
        coreUI.present(previewController, embedded: embedded)
    }

    // MARK: - On Dismiss

    public func onDismiss(_ perform: @escaping () -> Void) {
        _onDismiss = perform
    }

    // MARK: - QLPreviewControllerDataSource Conformance

    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        let amendedPath = filePath.removingOccurrences(of: ["file:///", "file://", "file:/"])
        return PreviewItem(title: previewItemTitle, url: URL(filePath: amendedPath))
    }

    // MARK: - QLPreviewControllerDelegate Conformance

    public func previewControllerDidDismiss(_ controller: QLPreviewController) {
        _onDismiss?()
    }
}
