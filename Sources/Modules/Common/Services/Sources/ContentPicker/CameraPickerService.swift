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

final class CameraPickerService: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI

    // MARK: - Properties

    private var _onDismiss: ((Callback<ContentPickerResult, Exception>?) -> Void)?

    // MARK: - Present

    func present() {
        let viewController = UIImagePickerController()
        viewController.delegate = self
        viewController.sourceType = .camera
        coreUI.present(viewController)
    }

    // MARK: - On Dismiss

    func onDismiss(_ perform: @escaping (Callback<ContentPickerResult, Exception>?) -> Void) {
        _onDismiss = perform
    }

    // MARK: - UIImagePickerControllerDelegate Conformance

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            _onDismiss?(.failure(.init("Failed to get image data.", metadata: .init(sender: self))))
            _onDismiss = nil
            return
        }

        _onDismiss?(.success(.image(image)))
        _onDismiss = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        _onDismiss?(nil)
        _onDismiss = nil
    }
}
