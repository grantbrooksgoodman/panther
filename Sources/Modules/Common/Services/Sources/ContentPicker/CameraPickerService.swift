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

/// Use ``CameraPickerService`` to capture a photo with the system camera interface.
///
/// Call ``present()`` to show the camera, and register a dismissal handler with
/// ``onDismiss(_:)`` to receive the captured image.
final class CameraPickerService: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI

    // MARK: - Properties

    private var _onDismiss: ((Callback<ContentPickerResult, Exception>?) -> Void)?

    // MARK: - Init

    /// Creates a camera picker service.
    override nonisolated init() {}

    // MARK: - Present

    /// Presents the system camera interface for capturing a photo.
    func present() {
        let viewController = UIImagePickerController()
        viewController.delegate = self
        viewController.sourceType = .camera
        coreUI.present(viewController)
    }

    // MARK: - On Dismiss

    /// Registers a handler to run when the picker is dismissed.
    ///
    /// The handler receives the selected item on success, a failure if processing fails, or
    /// `nil` if the user cancels. The handler is cleared after it runs. Registering a new
    /// handler replaces any existing one.
    ///
    /// - Parameter perform: The handler to run.
    func onDismiss(_ perform: @escaping (Callback<ContentPickerResult, Exception>?) -> Void) {
        _onDismiss = perform
    }

    // MARK: - UIImagePickerControllerDelegate Conformance

    /// Dismisses the picker and delivers the captured image to the dismissal handler.
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

    /// Dismisses the picker and delivers `nil` to the dismissal handler.
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        _onDismiss?(nil)
        _onDismiss = nil
    }
}
