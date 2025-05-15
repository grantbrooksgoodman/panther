//
//  DocumentExportService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

public final class DocumentExportService: NSObject, UIDocumentPickerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private var temporaryFilePath: URL?

    // MARK: - Present Export Controller

    public func presentExportController(forFileAt url: URL) -> Exception? {
        guard let fileExtension = url.path().components(separatedBy: "/").last?.components(separatedBy: ".").last else {
            return .init(
                "Failed to determine file type.",
                metadata: [self, #file, #function, #line]
            )
        }

        let temporaryFilePath = fileManager
            .temporaryDirectory
            .appending(path: "\(Localized(.attachment).wrappedValue.lowercased()).\(fileExtension)")

        if let exception = fileManager.copy(
            fileAt: url,
            toPath: temporaryFilePath
        ) {
            return exception
        }

        let viewController = UIDocumentPickerViewController(forExporting: [temporaryFilePath], asCopy: true)

        self.temporaryFilePath = temporaryFilePath
        viewController.delegate = self

        StatusBar.overrideStyle(.lightContent)
        coreUI.present(viewController)
        return nil
    }

    // MARK: - UIDocumentPickerDelegate Conformance

    public func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        controller.dismiss(animated: true)
        onDismiss()
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        onDismiss()
    }

    // MARK: - Auxiliary

    private func onDismiss() {
        defer { StatusBar.restoreStyle() }
        guard let temporaryFilePath else { return }
        try? fileManager.removeItem(at: temporaryFilePath)
        self.temporaryFilePath = nil
    }
}
