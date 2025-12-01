//
//  DocumentPickerService.swift
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

final class DocumentPickerService: NSObject, UIDocumentPickerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private var timeout: Timeout?
    private var _onDismiss: ((Callback<ContentPickerResult, Exception>?) -> Void)?

    // MARK: - Present

    func present() {
        let viewController = UIDocumentPickerViewController(forOpeningContentTypes: [
            .jpeg,
            .mpeg4Movie,
            .pdf,
            .png,
        ])
        viewController.delegate = self
        core.ui.present(viewController)
    }

    // MARK: - On Dismiss

    func onDismiss(_ perform: @escaping (Callback<ContentPickerResult, Exception>?) -> Void) {
        _onDismiss = perform
    }

    // MARK: - UIDocumentPickerDelegate Conformance

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        controller.dismiss(animated: true)

        guard let firstURL = urls.first else { return _onDismiss = nil }
        timeout = .init(after: .seconds(1)) { self.core.hud.showProgress(isModal: true) }
        processURL(firstURL)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        dismiss(nil)
    }

    // MARK: - Auxiliary

    private func dismiss(_ result: Callback<ContentPickerResult, Exception>?) {
        timeout?.cancel()
        core.hud.hide()

        _onDismiss?(result)
        _onDismiss = nil
    }

    private func processURL(_ url: URL) {
        guard let fileExtension = url.path().components(separatedBy: "/").last?.components(separatedBy: ".").last else {
            dismiss(.failure(.init(
                "Failed to determine file type.",
                metadata: .init(sender: self)
            )))
            return
        }

        typealias Strings = AppConstants.Strings.ChatPageViewService.MediaActionHandler
        let temporaryFileName = "\(Strings.defaultDocumentName).\(fileExtension)"
        let temporaryFilePath = fileManager.temporaryDirectory.appending(path: temporaryFileName)
        try? fileManager.removeItem(atPath: temporaryFilePath.path())

        guard url.startAccessingSecurityScopedResource() else {
            dismiss(.failure(.init(
                "Failed to access security-scoped URL.",
                metadata: .init(sender: self)
            )))
            return
        }

        do {
            try fileManager.copyItem(at: url, to: temporaryFilePath)
            url.stopAccessingSecurityScopedResource()

            if fileExtension == MediaFileExtension.image(.jpeg).rawValue ||
                fileExtension == MediaFileExtension.image(.jpg).rawValue ||
                fileExtension == MediaFileExtension.image(.png).rawValue,
                let image = UIImage(contentsOfFile: temporaryFilePath.path()) {
                dismiss(.success(.image(image)))
            } else if fileExtension == MediaFileExtension.video(.mp4).rawValue {
                dismiss(.success(.video(temporaryFilePath)))
            } else {
                dismiss(.success(.document(temporaryFilePath)))
            }
        } catch {
            dismiss(.failure(.init(error, metadata: .init(sender: self))))
            url.stopAccessingSecurityScopedResource()
        }
    }
}
