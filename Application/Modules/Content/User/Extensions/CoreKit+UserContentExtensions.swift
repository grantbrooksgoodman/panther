//
//  CoreKit+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public extension CoreKit.HUD {
    func flashNoSpeechDetected() {
        @Dependency(\.mainQueue) var mainQueue: DispatchQueue
        mainQueue.async {
            ProgressHUD.show(
                Localized(.noSpeechDetected).wrappedValue,
                icon: .micSlash
            )
        }
    }

    func flashRecordingInstruction() {
        @Dependency(\.mainQueue) var mainQueue: DispatchQueue
        mainQueue.async {
            ProgressHUD.show(
                Localized(.holdDownToRecord).wrappedValue,
                icon: .mic
            )
        }
    }
}
