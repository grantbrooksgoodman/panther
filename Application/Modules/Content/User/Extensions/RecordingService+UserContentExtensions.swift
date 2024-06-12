//
//  RecordingService+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public extension RecordingService {
    var isInOrWillTransitionToRecordingState: Bool {
        @Dependency(\.chatPageViewService.recordingUI?.isShowingRecordingUI) var isShowingRecordingUI: Bool?
        guard !isRecording,
              !willStartRecording else { return true }
        return isShowingRecordingUI ?? false
    }
}
