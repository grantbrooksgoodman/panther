//
//  CameraPickerView+Coordinator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension CameraPickerView {
    /// The object that receives the camera picker's delegate callbacks.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        // MARK: - Properties

        private let delegate: any ContentPicker<UIImage>

        // MARK: - Init

        /// Creates a coordinator that forwards callbacks to the given picker.
        ///
        /// - Parameter delegate: The picker whose handlers receive the callbacks.
        init(delegate: any ContentPicker<UIImage>) {
            self.delegate = delegate
        }

        // MARK: - UIImagePickerControllerDelegate Conformance

        /// Delivers `nil` to the dismissal handler.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            delegate.onDismiss(nil)
        }

        /// Delivers the captured image to the selection handler, followed by `nil` to the
        /// dismissal handler. If the image cannot be resolved, the dismissal handler receives
        /// an `Exception` instead.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                return delegate.onDismiss(.init(
                    "Failed to get image data.",
                    metadata: .init(sender: self)
                ))
            }

            delegate.onSelection(image)
            delegate.onDismiss(nil)
        }
    }
}

extension CameraPickerView.Coordinator: UIAdaptivePresentationControllerDelegate {
    /// Delivers `nil` to the dismissal handler when the user dismisses the picker with a
    /// gesture.
    func presentationControllerDidDismiss(
        _ presentationController: UIPresentationController
    ) {
        delegate.onDismiss(nil)
    }
}
