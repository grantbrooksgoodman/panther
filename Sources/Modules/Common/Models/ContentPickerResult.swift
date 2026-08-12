//
//  ContentPickerResult.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/// An item the user selected with a content picker.
enum ContentPickerResult {
    /// A document at the given local URL.
    case document(URL)

    /// An image.
    case image(UIImage)

    /// A video at the given local URL.
    case video(URL)
}
