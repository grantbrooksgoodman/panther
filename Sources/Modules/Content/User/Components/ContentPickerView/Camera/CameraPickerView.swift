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

public struct CameraPickerView: UIViewControllerRepresentable, ContentPicker {
    // MARK: - Type Aliases

    public typealias Content = UIImage

    // MARK: - Properties

    public var onDismiss: (Exception?) -> Void
    public var onSelection: (UIImage) -> Void

    // MARK: - Init

    public init(
        onSelection: @escaping (UIImage) -> Void,
        onDismiss: @escaping ((Exception?) -> Void)
    ) {
        self.onSelection = onSelection
        self.onDismiss = onDismiss
    }

    // MARK: - Make Coordinator

    public func makeCoordinator() -> Coordinator {
        .init(delegate: self)
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        imagePickerController.sourceType = .camera
        return imagePickerController
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
