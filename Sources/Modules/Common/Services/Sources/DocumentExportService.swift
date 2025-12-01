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

final class DocumentExportService: NSObject, UIDocumentPickerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private var temporaryFilePath: URL?
    private var _onDismiss: ((Bool) -> Void)?

    // MARK: - Present Export Controller

    func presentExportController(forFileAt url: URL) -> Exception? {
        guard let fileExtension = url.path().components(separatedBy: "/").last?.components(separatedBy: ".").last else {
            return .init(
                "Failed to determine file type.",
                metadata: .init(sender: self)
            )
        }

        let temporaryFilePath = fileManager
            .temporaryDirectory
            .appending(path: "\(Localized(.document).wrappedValue.lowercased()).\(fileExtension)")

        if let exception = fileManager.copy(
            fileAt: url,
            toPath: temporaryFilePath
        ) {
            return exception
        }

        let viewController = UIDocumentPickerViewController(forExporting: [temporaryFilePath], asCopy: true)

        self.temporaryFilePath = temporaryFilePath
        viewController.delegate = self

        StatusBar.overrideStyle(.conditionalLightContent)
        coreUI.present(viewController)
        return nil
    }

    // MARK: - On Dismiss

    func onDismiss(_ perform: @escaping (Bool) -> Void) {
        _onDismiss = perform
    }

    // MARK: - UIDocumentPickerDelegate Conformance

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        controller.dismiss(animated: true)
        onDismiss(cancelled: false)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true) {
            StatusBar.overrideStyle(.appAware)
            self.onDismiss(cancelled: true)
        }
    }

    // MARK: - Auxiliary

    private func onDismiss(cancelled: Bool) {
        defer {
            _onDismiss?(cancelled)
            _onDismiss = nil
        }

        guard let temporaryFilePath else { return }
        try? fileManager.removeItem(at: temporaryFilePath)
        self.temporaryFilePath = nil
    }
}
