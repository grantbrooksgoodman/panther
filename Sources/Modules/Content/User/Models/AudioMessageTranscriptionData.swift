//
//  AudioMessageTranscriptionData.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/07/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The context needed to transcribe an audio message.
struct AudioMessageTranscriptionData {
    /// The ID key of the conversation containing the message.
    let conversationIDKey: String

    /// The audio file to transcribe.
    let inputFile: AudioFile

    /// A Boolean value that indicates whether the conversation is a PenPals conversation.
    let isPenPalsConversation: Bool
}
