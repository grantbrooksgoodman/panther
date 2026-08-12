//
//  RecordButtonCommand.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A command issued by the record button.
enum RecordButtonCommand {
    /// Stops the recording and deletes its output file.
    case cancelRecording

    /// Starts recording audio.
    case startRecording

    /// Stops the recording, keeping its output file.
    case stopRecording
}
