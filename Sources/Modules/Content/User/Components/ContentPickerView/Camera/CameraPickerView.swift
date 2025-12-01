//
//  CameraPickerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

struct CameraPickerView: UIViewControllerRepresentable, ContentPicker {
    // MARK: - Type Aliases

    typealias Content = UIImage

    // MARK: - Properties

    var onDismiss: (Exception?) -> Void
    var onSelection: (UIImage) -> Void

    // MARK: - Init

    init(
        onSelection: @escaping (UIImage) -> Void,
        onDismiss: @escaping ((Exception?) -> Void)
    ) {
        self.onSelection = onSelection
        self.onDismiss = onDismiss
    }

    // MARK: - Make Coordinator

    func makeCoordinator() -> Coordinator {
        .init(delegate: self)
    }

    // MARK: - Make UIViewController

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        imagePickerController.sourceType = .camera
        return imagePickerController
    }

    // MARK: - Update UIViewController

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
