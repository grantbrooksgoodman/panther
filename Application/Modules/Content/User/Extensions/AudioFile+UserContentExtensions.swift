//
//  AudioFile+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

extension AudioFile: AudioItem {
    public var duration: Float { contentDuration ?? 0 }

    public var size: CGSize {
        typealias Floats = AppConstants.CGFloats.UserContentExtensions.AudioItem
        return .init(width: Floats.sizeWidth, height: Floats.sizeHeight)
    }
}
