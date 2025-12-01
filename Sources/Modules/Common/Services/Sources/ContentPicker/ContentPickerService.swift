//
//  ContentPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ContentPickerService {
    // MARK: - Properties

    let camera: CameraPickerService
    let document: DocumentPickerService
    let media: MediaPickerService

    // MARK: - Init

    init(
        camera: CameraPickerService,
        document: DocumentPickerService,
        media: MediaPickerService
    ) {
        self.camera = camera
        self.document = document
        self.media = media
    }
}
