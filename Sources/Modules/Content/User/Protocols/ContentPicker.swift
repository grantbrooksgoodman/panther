//
//  ContentPicker.swift
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

/// The interface for views that pick content and report results through handlers.
protocol ContentPicker<Content> {
    /// The type of content the picker selects.
    associatedtype Content

    /// The handler that runs when the picker is dismissed, receiving an `Exception` if
    /// selection failed; otherwise, `nil`.
    var onDismiss: (Exception?) -> Void { get }

    /// The handler that receives the selected content.
    var onSelection: (Content) -> Void { get }
}

@MainActor
extension ContentPicker {
    /// Assigns the given context's coordinator as the presentation controller delegate of the
    /// presented hierarchy, so dismissal gestures reach the coordinator.
    ///
    /// The delegate is assigned to the SwiftUI presentation hosting controllers when present;
    /// otherwise, to every presented controller.
    ///
    /// - Parameter context: The representable context whose coordinator receives the
    ///   delegate callbacks.
    func setPresentationControllerDelegate<T>(
        _ context: UIViewControllerRepresentableContext<T>
    ) where T.Coordinator: UIAdaptivePresentationControllerDelegate {
        @Dependency(\.uiApplication.presentedViewControllers) var presentedViewControllers: [UIViewController]

        let presentationControllers = presentedViewControllers
            .compactMap(\.presentationController)

        let presentationHostingControllers = presentationControllers
            .filter {
                $0.presentedViewController.children.isEmpty &&
                    $0.presentedViewController.descriptor == "PresentationHostingController<AnyView>"
            }

        (
            presentationHostingControllers.isEmpty ?
                presentationControllers :
                presentationHostingControllers
        )
        .forEach { $0.delegate = context.coordinator }
    }
}

extension Exception {
    static func contentPickerContentTypeMismatch(
        _ metadata: ExceptionMetadata
    ) -> Exception {
        .init(
            "Failed to typecast result to specified content.",
            metadata: metadata
        )
    }
}
