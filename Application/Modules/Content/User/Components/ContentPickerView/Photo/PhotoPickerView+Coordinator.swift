//
//  PhotoPickerView+Coordinator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import PhotosUI
import UIKit

/* Proprietary */
import AppSubsystem

public extension PhotoPickerView {
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        // MARK: - Dependencies

        @Dependency(\.mainQueue) private var mainQueue: DispatchQueue

        // MARK: - Properties

        private let delegate: any ContentPicker<UIImage>

        // MARK: - Init

        public init(delegate: any ContentPicker<UIImage>) {
            self.delegate = delegate
        }

        // MARK: - PHPickerViewControllerDelegate Conformance

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            var exception: Exception?
            defer { delegate.dismiss(exception) }

            guard let itemProvider = results.first?.itemProvider,
                  itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

            itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                guard let image = object as? UIImage else {
                    exception = .init(error, metadata: [self, #file, #function, #line])
                    return
                }

                self.mainQueue.async { self.delegate.onSelection(image) }
            }
        }
    }
}
