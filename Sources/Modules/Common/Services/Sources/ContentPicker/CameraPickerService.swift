//
//  CameraPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import PhotosUI

/* Proprietary */
import AppSubsystem

public final class CameraPickerService: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI

    // MARK: - Properties

    private var _onDismiss: ((Callback<ContentPickerResult, Exception>?) -> Void)?

    // MARK: - Present

    public func present() {
        let viewController = UIImagePickerController()
        viewController.delegate = self
        viewController.sourceType = .camera
        coreUI.present(viewController)
    }

    // MARK: - On Dismiss

    public func onDismiss(_ perform: @escaping (Callback<ContentPickerResult, Exception>?) -> Void) {
        _onDismiss = perform
    }

    // MARK: - UIImagePickerControllerDelegate Conformance

    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            _onDismiss?(.failure(.init("Failed to get image data.", metadata: [self, #file, #function, #line])))
            _onDismiss = nil
            return
        }

        _onDismiss?(.success(.image(image)))
        _onDismiss = nil
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        _onDismiss?(nil)
        _onDismiss = nil
    }
}
