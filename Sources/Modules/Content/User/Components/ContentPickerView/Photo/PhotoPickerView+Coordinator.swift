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
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        // MARK: - Properties

        private let delegate: any ContentPicker<UIImage>

        // MARK: - Init

        init(delegate: any ContentPicker<UIImage>) {
            self.delegate = delegate
        }

        // MARK: - PHPickerViewControllerDelegate Conformance

        func picker(
            _ picker: PHPickerViewController,
            didCancelWithError error: Error?
        ) {
            delegate.onDismiss(.init(
                error,
                metadata: .init(sender: self)
            ))
        }

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
    func presentationControllerDidDismiss(
        _ presentationController: UIPresentationController
    ) {
        delegate.onDismiss(nil)
    }
}
