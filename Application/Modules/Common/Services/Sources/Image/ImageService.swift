//
//  ImageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ImageService {
    // MARK: - Properties

    public let photoPicker: PhotoPickerService

    // MARK: - Init

    public init(photoPicker: PhotoPickerService) {
        self.photoPicker = photoPicker
    }
}
