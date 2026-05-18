//
//  ConversationMetadata+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension ConversationMetadata: Serializable {
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    enum SerializableKey: String {
        case name
        case imageData
        case isPenPalsConversation
        case lastModifiedDate = "lastModified" // swiftlint:disable:next identifier_name
        case messageRecipientConsentAcknowledgementData
        case penPalsSharingData
        case requiresConsentFromInitiator
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.name.rawValue: name,
            Keys.imageData.rawValue: imageData?.base64EncodedString() ?? .bangQualifiedEmpty,
            Keys.isPenPalsConversation.rawValue: isPenPalsConversation,
            Keys.lastModifiedDate.rawValue: dateFormatter.string(from: lastModifiedDate),
            Keys.messageRecipientConsentAcknowledgementData.rawValue: messageRecipientConsentAcknowledgementData.map(\.encoded).sorted(),
            Keys.penPalsSharingData.rawValue: penPalsSharingData.map(\.encoded).sorted(),
            Keys.requiresConsentFromInitiator.rawValue: requiresConsentFromInitiator ?? .bangQualifiedEmpty,
        ]
    }

    // MARK: - Init

    init(
        from data: [String: Any]
    ) async throws(Exception) {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        // swiftlint:disable identifier_name
        guard let name = data[Keys.name.rawValue] as? String,
              let imageDataString = data[Keys.imageData.rawValue] as? String,
              let isPenPalsConversation = data[Keys.isPenPalsConversation.rawValue] as? Bool,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              let lastModifiedDate = dateFormatter.date(from: lastModifiedDateString),
              let encodedMessageRecipientConsentAcknowledgementData = data[Keys.messageRecipientConsentAcknowledgementData.rawValue] as? [String],
              let encodedPenPalsSharingData = data[Keys.penPalsSharingData.rawValue] as? [String],
              let requiesConsentFromInitiator = data[Keys.requiresConsentFromInitiator.rawValue] as? String else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let messageRecipientConsentAcknowledgementData = try await encodedMessageRecipientConsentAcknowledgementData
            .parallelMap {
                try await MessageRecipientConsentAcknowledgementData(from: $0)
            }

        // swiftlint:enable identifier_name
        let penPalsSharingData = try await encodedPenPalsSharingData.parallelMap {
            try await PenPalsSharingData(from: $0)
        }

        guard !messageRecipientConsentAcknowledgementData.isEmpty,
              !penPalsSharingData.isEmpty,
              messageRecipientConsentAcknowledgementData.count == encodedMessageRecipientConsentAcknowledgementData.count,
              penPalsSharingData.count == encodedPenPalsSharingData.count else {
            throw Exception(
                "Mismatched ratio returned.",
                metadata: .init(sender: Self.self)
            )
        }

        guard !imageDataString.isBangQualifiedEmpty else {
            self = .init(
                name: name,
                imageData: nil,
                isPenPalsConversation: isPenPalsConversation,
                lastModifiedDate: lastModifiedDate,
                messageRecipientConsentAcknowledgementData: messageRecipientConsentAcknowledgementData,
                penPalsSharingData: penPalsSharingData,
                requiresConsentFromInitiator: requiesConsentFromInitiator.isBangQualifiedEmpty ? nil : requiesConsentFromInitiator
            )
            return
        }

        guard let imageData = Data(base64Encoded: imageDataString) else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self = .init(
            name: name,
            imageData: imageData,
            isPenPalsConversation: isPenPalsConversation,
            lastModifiedDate: lastModifiedDate,
            messageRecipientConsentAcknowledgementData: messageRecipientConsentAcknowledgementData,
            penPalsSharingData: penPalsSharingData,
            requiresConsentFromInitiator: requiesConsentFromInitiator.isBangQualifiedEmpty ? nil : requiesConsentFromInitiator
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.name.rawValue] is String,
              let imageDataString = data[Keys.imageData.rawValue] as? String,
              imageDataString.isBangQualifiedEmpty || Data(base64Encoded: imageDataString) != nil,
              data[Keys.isPenPalsConversation.rawValue] is Bool,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              dateFormatter.date(from: lastModifiedDateString) != nil, // swiftlint:disable:next identifier_name
              let encodedMessageRecipientConsentAcknowledgementData = data[Keys.messageRecipientConsentAcknowledgementData.rawValue] as? [String],
              encodedMessageRecipientConsentAcknowledgementData.allSatisfy({ MessageRecipientConsentAcknowledgementData.canDecode(from: $0) }),
              let encodedPenPalsSharingData = data[Keys.penPalsSharingData.rawValue] as? [String],
              encodedPenPalsSharingData.allSatisfy({ PenPalsSharingData.canDecode(from: $0) }),
              encodedMessageRecipientConsentAcknowledgementData.count == encodedPenPalsSharingData.count,
              data[Keys.requiresConsentFromInitiator.rawValue] is String else { return false }

        return true
    }
}
