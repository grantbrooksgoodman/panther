//
//  MediaPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct MediaPickerService {
    // MARK: - Properties

    public let camera: CameraPickerService
    public let photo: PhotoPickerService

    // MARK: - Init

    public init(
        camera: CameraPickerService,
        photo: PhotoPickerService
    ) {
        self.camera = camera
        self.photo = photo
    }
}
