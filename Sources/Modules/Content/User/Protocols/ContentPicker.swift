//
//  ContentPicker.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

protocol ContentPicker<Content> {
    associatedtype Content

    var onDismiss: (Exception?) -> Void { get }
    var onSelection: (Content) -> Void { get }
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
