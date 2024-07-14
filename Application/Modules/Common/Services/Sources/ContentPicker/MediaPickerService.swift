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

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class MediaPickerService: PHPickerViewControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit

    // MARK: - Properties

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
            return
        }

        let confirmAction: AKAction = .init("Confirm", style: .preferred) {
            self.core.gcd.after(.milliseconds(250)) {
                picker.dismiss(animated: true)

                guard let itemProvider = results.first?.itemProvider else { return }
                let timeout = Timeout(after: .seconds(1)) { self.core.hud.showProgress(isModal: true) }

                if itemProvider.canLoadObject(ofClass: UIImage.self) {
                    itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        timeout.cancel()
                        self.core.hud.hide()

                        guard let image = object as? UIImage else {
                            self._onDismiss?(.failure(.init(error, metadata: [self, #file, #function, #line])))
                            self._onDismiss = nil
                            return
                        }

                        self._onDismiss?(.success(.image(image)))
                        self._onDismiss = nil
                    }
                } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    itemProvider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { object, error in
                        timeout.cancel()
                        self.core.hud.hide()

                        guard let url = object as? URL else {
                            self._onDismiss?(.failure(.init(error, metadata: [self, #file, #function, #line])))
                            self._onDismiss = nil
                            return
                        }

                        self._onDismiss?(.success(.video(url)))
                        self._onDismiss = nil
                    }
                } else {
                    timeout.cancel()
                    self.core.hud.hide()

                    self._onDismiss?(.failure(.init("Failed to process media.", metadata: [self, #file, #function, #line])))
                    self._onDismiss = nil
                }
            }
        }

        Task {
            await AKActionSheet(actions: [
                confirmAction,
                .cancelAction,
            ]).present(translating: [.actions([confirmAction])])
        }
    }
}
