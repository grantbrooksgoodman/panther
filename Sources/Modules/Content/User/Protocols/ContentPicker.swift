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

protocol ContentPicker<Content> {
    associatedtype Content

    var onDismiss: (Exception?) -> Void { get }
    var onSelection: (Content) -> Void { get }
}

@MainActor
extension ContentPicker {
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
