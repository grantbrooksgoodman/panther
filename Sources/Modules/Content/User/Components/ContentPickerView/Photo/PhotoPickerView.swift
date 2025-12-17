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

struct PhotoPickerView: UIViewControllerRepresentable, ContentPicker {
    // MARK: - Type Aliases

    typealias Content = UIImage

    // MARK: - Dependencies

    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue

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

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = context.coordinator
        return pickerViewController
    }

    // MARK: - Update UIViewController

    func updateUIViewController(
        _ uiViewController: PHPickerViewController,
        context: Context
    ) {
        mainQueue.async {
            uiViewController.parent?.presentationController?.delegate = context.coordinator
        }
    }
}
