//
//  ContentPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The umbrella service for content picking.
///
/// Use ``ContentPickerService`` to access the app's content picker services, each of which
/// presents a system interface for selecting a ``ContentPickerResult`` item.
struct ContentPickerService {
    /// The service that captures a photo with the system camera interface.
    let camera: CameraPickerService

    /// The service that chooses a file with the system document picker.
    let document: DocumentPickerService

    /// The service that chooses a photo or video from the user's photo library.
    let media: MediaPickerService
}
