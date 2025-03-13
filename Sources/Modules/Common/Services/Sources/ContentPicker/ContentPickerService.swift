//
//  ContentPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ContentPickerService {
    // MARK: - Properties

    public let camera: CameraPickerService
    public let document: DocumentPickerService
    public let media: MediaPickerService

    // MARK: - Init

    public init(
        camera: CameraPickerService,
        document: DocumentPickerService,
        media: MediaPickerService
    ) {
        self.camera = camera
        self.document = document
        self.media = media
    }
}
