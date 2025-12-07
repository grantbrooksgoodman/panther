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
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        // MARK: - Properties

        private let delegate: any ContentPicker<UIImage>

        // MARK: - Init

        init(delegate: any ContentPicker<UIImage>) {
            self.delegate = delegate
        }

        // MARK: - UIImagePickerControllerDelegate Conformance

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

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            delegate.onDismiss(nil)
        }
    }
}
