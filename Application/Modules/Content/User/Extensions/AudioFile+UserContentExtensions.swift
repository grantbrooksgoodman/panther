//
//  AudioFile+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import MessageKit

extension AudioFile: AudioItem {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.AudioItem

    // MARK: - Properties

    public var duration: Float { contentDuration ?? 0 }
    public var size: CGSize { .init(width: Floats.sizeWidth, height: Floats.sizeHeight) }
}
