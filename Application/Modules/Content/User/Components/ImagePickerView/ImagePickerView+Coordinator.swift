//
//  ImagePickerView+Coordinator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public extension ImagePickerView {
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        // MARK: - Properties

        private let onDismiss: () -> Void
        private let onSelection: (UIImage) -> Void

        // MARK: - Init

        public init(onDismiss: @escaping () -> Void, onSelection: @escaping (UIImage) -> Void) {
            self.onDismiss = onDismiss
            self.onSelection = onSelection
        }

        // MARK: - UIImagePickerControllerDelegate Conformance

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onSelection(image)
            }
            onDismiss()
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }
    }
}
