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

extension PhotoPickerView {
    /// The object that receives the photo picker's delegate callbacks.
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        // MARK: - Properties

        private let delegate: any ContentPicker<UIImage>

        // MARK: - Init

        /// Creates a coordinator that forwards callbacks to the given picker.
        ///
        /// - Parameter delegate: The picker whose handlers receive the callbacks.
        init(delegate: any ContentPicker<UIImage>) {
            self.delegate = delegate
        }

        // MARK: - PHPickerViewControllerDelegate Conformance

        /// Delivers an `Exception` wrapping the given error to the dismissal handler.
        func picker(
            _ picker: PHPickerViewController,
            didCancelWithError error: Error?
        ) {
            delegate.onDismiss(.init(
                error,
                metadata: .init(sender: self)
            ))
        }

        /// Loads the first picked image and delivers it to the selection handler, followed by
        /// `nil` to the dismissal handler. If nothing was picked, the dismissal handler
        /// receives `nil`; if loading fails, it receives an `Exception` instead.
        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            guard let itemProvider = results.first?.itemProvider,
                  itemProvider.canLoadObject(ofClass: UIImage.self) else {
                return delegate.onDismiss(nil)
            }

            itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                guard let image = object as? UIImage else {
                    Task { @MainActor [weak self] in
                        self?.delegate.onDismiss(.init(
                            error,
                            metadata: .init(sender: Self.self)
                        ))
                    }
                    return
                }

                Task { @MainActor [weak self] in
                    self?.delegate.onSelection(image)
                    self?.delegate.onDismiss(nil)
                }
            }
        }
    }
}

extension PhotoPickerView.Coordinator: UIAdaptivePresentationControllerDelegate {
    /// Delivers `nil` to the dismissal handler when the user dismisses the picker with a
    /// gesture.
    func presentationControllerDidDismiss(
        _ presentationController: UIPresentationController
    ) {
        delegate.onDismiss(nil)
    }
}
