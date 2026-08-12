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

/// A view that presents the system camera interface for capturing a photo.
///
/// When the user picks an image, the selection handler runs, followed by the dismissal
/// handler with `nil`. If the picker is canceled, dismissed without a selection, or fails to
/// load the picked image, only the dismissal handler runs – with an `Exception` describing
/// any failure; otherwise, `nil`.
struct CameraPickerView: UIViewControllerRepresentable, @MainActor ContentPicker {
    // MARK: - Type Aliases

    /// The type of content the picker selects.
    typealias Content = UIImage

    // MARK: - Properties

    /// The handler that runs when the picker is dismissed, receiving an `Exception` if
    /// selection failed; otherwise, `nil`.
    var onDismiss: (Exception?) -> Void

    /// The handler that receives the selected content.
    var onSelection: (UIImage) -> Void

    // MARK: - Init

    /// Creates a camera picker with the given handlers.
    ///
    /// - Parameters:
    ///   - onSelection: The handler that receives the selected content.
    ///   - onDismiss: The handler that runs when the picker is dismissed, receiving an
    ///     `Exception` if selection failed; otherwise, `nil`.
    init(
        onSelection: @escaping (UIImage) -> Void,
        onDismiss: @escaping ((Exception?) -> Void)
    ) {
        self.onSelection = onSelection
        self.onDismiss = onDismiss
    }

    // MARK: - Make Coordinator

    /// Creates the coordinator that receives the picker's delegate callbacks.
    func makeCoordinator() -> Coordinator {
        .init(delegate: self)
    }

    // MARK: - Make UIViewController

    /// Creates the image picker controller configured for camera capture.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        imagePickerController.sourceType = .camera
        return imagePickerController
    }

    // MARK: - Update UIViewController

    /// Assigns the coordinator as the presentation controller delegate of the presented
    /// hierarchy, so dismissal gestures invoke the dismissal handler.
    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {
        setPresentationControllerDelegate(context)
    }
}
