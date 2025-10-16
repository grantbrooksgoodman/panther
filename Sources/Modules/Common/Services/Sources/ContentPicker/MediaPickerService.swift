//
//  MediaPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import PhotosUI

/* Proprietary */
import AlertKit
import AppSubsystem

public final class MediaPickerService: PHPickerViewControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private var timeout: Timeout?
    private var _onDismiss: ((Callback<ContentPickerResult, Exception>?) -> Void)?

    // MARK: - Present

    public func present() {
        let viewController = PHPickerViewController(configuration: .init())
        viewController.delegate = self
        viewController.isModalInPresentation = true
        core.ui.present(viewController)
    }

    // MARK: - On Dismiss

    public func onDismiss(_ perform: @escaping (Callback<ContentPickerResult, Exception>?) -> Void) {
        _onDismiss = perform
    }

    // MARK: - PHPickerViewControllerDelegate Conformance

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard !results.isEmpty else {
            picker.dismiss(animated: true)
            _onDismiss?(nil)
            _onDismiss = nil
            return
        }

        let confirmAction: AKAction = .init("Confirm", style: .preferred) {
            self.core.gcd.after(.milliseconds(250)) {
                picker.dismiss(animated: true)

                guard let itemProvider = results.first?.itemProvider else { return self._onDismiss = nil }
                self.timeout = .init(after: .seconds(1)) { self.core.hud.showProgress(isModal: true) }

                if itemProvider.canLoadObject(ofClass: UIImage.self) {
                    self.loadImage(itemProvider)
                } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    self.loadVideo(itemProvider)
                } else {
                    self.dismissReturningFailure(.init("Failed to process media.", metadata: .init(sender: self)))
                }
            }
        }

        Task {
            await AKActionSheet(
                actions: [confirmAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions()])
        }
    }

    // MARK: - Auxiliary

    private func dismissReturningFailure(_ exception: Exception) {
        timeout?.cancel()
        core.hud.hide()

        _onDismiss?(.failure(exception))
        _onDismiss = nil
    }

    private func loadImage(_ itemProvider: NSItemProvider) {
        itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            self.timeout?.cancel()
            self.core.hud.hide()

            guard let image = object as? UIImage else {
                return self.dismissReturningFailure(.init(error, metadata: .init(sender: self)))
            }

            self._onDismiss?(.success(.image(image)))
            self._onDismiss = nil
        }
    }

    private func loadVideo(_ itemProvider: NSItemProvider) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            self.timeout?.cancel()
            self.core.hud.hide()

            guard let url else {
                return self.dismissReturningFailure(.init(error, metadata: .init(sender: self)))
            }

            typealias Strings = AppConstants.Strings.ChatPageViewService.MediaActionHandler
            let temporaryFileName = "\(Strings.defaultVideoName).\(MediaFileExtension.video(.mp4).rawValue)"
            let temporaryFilePath = self.fileManager.temporaryDirectory.appending(path: temporaryFileName)
            try? self.fileManager.removeItem(atPath: temporaryFilePath.path())

            do {
                try self.fileManager.copyItem(at: url, to: temporaryFilePath)
                self._onDismiss?(.success(.video(temporaryFilePath)))
                self._onDismiss = nil
            } catch {
                self.dismissReturningFailure(.init(error, metadata: .init(sender: self)))
            }
        }
    }
}
