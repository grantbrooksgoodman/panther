//
//  ContentPickerContentSource.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The source from which a content picker selects content.
enum ContentPickerContentSource {
    /// The device camera.
    case camera

    /// The user's photo library.
    case photoLibrary
}
