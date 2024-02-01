//
//  Message+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit

// swiftformat:disable acronyms

extension Message: MessageType {
    // MARK: - Types

    public struct Sender: SenderType {
        public let displayName: String
        public let senderId: String
    }

    // MARK: - Properties

    public var kind: MessageKind {
        guard hasAudioComponent,
              let audioComponent else { return .text(isFromCurrentUser ? translation.input.value() : translation.output) }

        let fileToUse = isFromCurrentUser ? audioComponent.original : audioComponent.translated
        return .audio(fileToUse)
    }

    public var messageId: String { id }
    public var sender: SenderType { Sender(displayName: "", senderId: fromAccountID) }
}

// swiftformat:enable acronyms

public extension Message {
    var backgroundColor: UIColor {
        isFromCurrentUser ? .senderBubble : .receiverBubble
    }

    static var empty: Message {
        .init(
            "",
            fromAccountID: "",
            hasAudioComponent: false,
            audioComponents: nil,
            translations: [
                .init(
                    input: .init(""),
                    output: "",
                    languagePair: .system
                ),
            ],
            readDate: nil,
            sentDate: .init()
        )
    }

    var isFromCurrentUser: Bool {
        @Persistent(.currentUserID) var currentUserID: String?
        return fromAccountID == currentUserID
    }

    var isMock: Bool { id == UserContentConstants.newMessageID }
}
