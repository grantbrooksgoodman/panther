//
//  PhotoPickerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import PhotosUI
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct PhotoPickerView: UIViewControllerRepresentable, ContentPicker {
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

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = context.coordinator
        return pickerViewController
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
