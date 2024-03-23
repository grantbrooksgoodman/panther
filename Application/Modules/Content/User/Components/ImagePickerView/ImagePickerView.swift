//
//  ImagePickerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public struct ImagePickerView: UIViewControllerRepresentable {
    // MARK: - Properties

    // Closure
    private let onDismiss: (() -> Void)?
    private let onSelection: (UIImage) -> Void

    // Other
    @Environment(\.presentationMode) private var presentationMode
    private var sourceType: UIImagePickerController.SourceType

    // MARK: - Init

    public init(
        _ sourceType: UIImagePickerController.SourceType,
        onSelection: @escaping (UIImage) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.sourceType = sourceType
        self.onSelection = onSelection
        self.onDismiss = onDismiss
    }

    // MARK: - Make Coordinator

    public func makeCoordinator() -> Coordinator {
        .init(onDismiss: _onDismiss, onSelection: onSelection)
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        imagePickerController.sourceType = sourceType
        return imagePickerController
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Auxiliary

    private func _onDismiss() {
        presentationMode.wrappedValue.dismiss()
        onDismiss?()
    }
}
