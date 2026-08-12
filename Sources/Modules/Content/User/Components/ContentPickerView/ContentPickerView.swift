//
//  ContentPickerView.swift
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

/// A view that presents a picker for selecting image content from a given source.
///
/// Use ``ContentPickerView`` to present either the camera or the photo library, according to
/// the given ``ContentPickerContentSource``. When the user picks an image, the selection
/// handler runs, followed by the dismissal handler with `nil`. If the picker is canceled,
/// dismissed without a selection, or fails to load the picked image, only the dismissal
/// handler runs – with an `Exception` describing any failure; otherwise, `nil`.
///
/// If the picked image cannot be cast to `Content`, the dismissal handler runs with a
/// content-type mismatch `Exception`.
struct ContentPickerView<Content>: View {
    // MARK: - Properties

    private let source: ContentPickerContentSource
    private let onSelection: (Content) -> Void
    private let onDismiss: (Exception?) -> Void

    // MARK: - Init

    /// Creates a content picker for the given source.
    ///
    /// - Parameters:
    ///   - source: The source from which to pick content.
    ///   - onSelection: The handler that receives the selected content.
    ///   - onDismiss: The handler that runs when the picker is dismissed, receiving an
    ///     `Exception` if selection failed; otherwise, `nil`.
    init(
        _ source: ContentPickerContentSource,
        onSelection: @escaping (Content) -> Void,
        onDismiss: @escaping (Exception?) -> Void
    ) {
        self.source = source
        self.onSelection = onSelection
        self.onDismiss = onDismiss
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        switch source {
        case .camera:
            CameraPickerView { image in
                guard let content = image as? Content else {
                    return onDismiss(.contentPickerContentTypeMismatch(.init(
                        sender: self
                    )))
                }

                onSelection(content)
            } onDismiss: { exception in
                onDismiss(exception)
            }

        case .photoLibrary:
            PhotoPickerView { image in
                guard let content = image as? Content else {
                    return onDismiss(.contentPickerContentTypeMismatch(.init(
                        sender: self
                    )))
                }

                onSelection(content)
            } onDismiss: { exception in
                onDismiss(exception)
            }
        }
    }
}
