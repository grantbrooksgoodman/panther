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

/// Use ``DocumentExportService`` to export a file with the system document picker.
///
/// Call ``presentExportController(forFileAt:)`` to show the picker, and register a dismissal
/// handler with ``onDismiss(_:)`` to respond when the export completes. The file is exported
/// from a temporary copy that is removed on dismissal.
final class DocumentExportService: NSObject, UIDocumentPickerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private var temporaryFilePath: URL?
    private var _onDismiss: ((Bool) -> Void)?

    // MARK: - Init

    /// Creates a document export service.
    override nonisolated init() {}

    // MARK: - Present Export Controller

    /// Presents the system document picker for exporting the file at the given URL.
    ///
    /// The file is copied to the app's temporary directory under a localized default name
    /// before presentation; the destination the user chooses receives a copy.
    ///
    /// - Parameter url: The URL of the file to export.
    ///
    /// - Throws: An `Exception` if the file type cannot be determined, or if the file cannot
    ///   be copied to the temporary directory.
    func presentExportController(
        forFileAt url: URL
    ) throws(Exception) {
        guard let fileExtension = url.path().components(separatedBy: "/").last?.components(separatedBy: ".").last else {
            throw Exception(
                "Failed to determine file type.",
                metadata: .init(sender: self)
            )
        }

        let temporaryFilePath = fileManager
            .temporaryDirectory
            .appending(path: "\(Localized(.document).wrappedValue.lowercased()).\(fileExtension)")

        try fileManager.copy(
            fileAt: url,
            toPath: temporaryFilePath
        )

        let viewController = UIDocumentPickerViewController(forExporting: [temporaryFilePath], asCopy: true)

        self.temporaryFilePath = temporaryFilePath
        viewController.delegate = self

        StatusBar.overrideStyle(.conditionalLightContent)
        coreUI.present(viewController)
    }

    // MARK: - On Dismiss

    /// Registers a handler to run when the picker is dismissed.
    ///
    /// The handler receives `true` if the user canceled the export; otherwise, `false`. The
    /// handler is cleared after it runs. Registering a new handler replaces any existing one.
    ///
    /// - Parameter perform: The handler to run.
    func onDismiss(
        _ perform: @escaping (Bool) -> Void
    ) {
        _onDismiss = perform
    }

    // MARK: - UIDocumentPickerDelegate Conformance

    /// Dismisses the picker and delivers `false` to the dismissal handler.
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        controller.dismiss(animated: true) {
            StatusBar.overrideStyle(.appAware)
            self.onDismiss(cancelled: false)
        }
    }

    /// Dismisses the picker and delivers `true` to the dismissal handler.
    func documentPickerWasCancelled(
        _ controller: UIDocumentPickerViewController
    ) {
        controller.dismiss(animated: true) {
            StatusBar.overrideStyle(.appAware)
            self.onDismiss(cancelled: true)
        }
    }

    // MARK: - Auxiliary

    private func onDismiss(
        cancelled: Bool
    ) {
        defer {
            _onDismiss?(cancelled)
            _onDismiss = nil
        }

        guard let temporaryFilePath else { return }
        try? fileManager.removeItem(at: temporaryFilePath)
        self.temporaryFilePath = nil
    }
}
