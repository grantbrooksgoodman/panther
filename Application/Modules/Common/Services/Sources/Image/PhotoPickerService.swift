//
//  PhotoPickerService.swift
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

public final class PhotoPickerService: PHPickerViewControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit

    // MARK: - Properties

    private var _onDismiss: ((Callback<UIImage, Exception>) -> Void)?

    // MARK: - Present

    public func present() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        let viewController = PHPickerViewController(configuration: configuration)
        viewController.delegate = self
        core.ui.present(viewController)
    }

    // MARK: - On Dismiss

    public func onDismiss(_ perform: @escaping (Callback<UIImage, Exception>) -> Void) {
        _onDismiss = perform
    }

    // MARK: - PHPickerViewControllerDelegate Conformance

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard !results.isEmpty else { return picker.dismiss(animated: true) }

        let confirmAction: AKAction = .init("Confirm", style: .preferred) {
            self.core.gcd.after(.milliseconds(250)) {
                picker.dismiss(animated: true)

                guard let itemProvider = results.first?.itemProvider,
                      itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

                let timeout = Timeout(after: .seconds(1)) { self.core.hud.showProgress(isModal: true) }
                itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    timeout.cancel()
                    self.core.hud.hide()

                    guard let image = object as? UIImage else {
                        self._onDismiss?(.failure(.init(error, metadata: [self, #file, #function, #line])))
                        self._onDismiss = nil
                        return
                    }

                    self._onDismiss?(.success(image))
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
