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

    typealias T = ConversationMetadata
    private typealias Keys = SerializationKeys

    // MARK: - Types

    enum SerializationKeys: String {
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

    // MARK: - Methods

    static func canDecode(from data: [String: Any]) -> Bool {
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

    static func decode(from data: [String: Any]) async -> Callback<ConversationMetadata, Exception> {
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
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        var messageRecipientConsentAcknowledgementData = [MessageRecipientConsentAcknowledgementData]()

        for encodedMessageRecipientConsentAcknowledgementDatum in encodedMessageRecipientConsentAcknowledgementData {
            let decodeResult = await MessageRecipientConsentAcknowledgementData.decode(from: encodedMessageRecipientConsentAcknowledgementDatum)

            switch decodeResult {
            case let .success(messageRecipientConsentAcknowledgementDatum):
                messageRecipientConsentAcknowledgementData.append(messageRecipientConsentAcknowledgementDatum)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        // swiftlint:enable identifier_name
        var penPalsSharingData = [PenPalsSharingData]()

        for encodedPenPalsSharingDatum in encodedPenPalsSharingData {
            let decodeResult = await PenPalsSharingData.decode(from: encodedPenPalsSharingDatum)

            switch decodeResult {
            case let .success(penPalsSharingDatum):
                penPalsSharingData.append(penPalsSharingDatum)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard !messageRecipientConsentAcknowledgementData.isEmpty,
              !penPalsSharingData.isEmpty,
              messageRecipientConsentAcknowledgementData.count == encodedMessageRecipientConsentAcknowledgementData.count,
              penPalsSharingData.count == encodedPenPalsSharingData.count else {
            return .failure(.init("Mismatched ratio returned.", metadata: .init(sender: self)))
        }

        guard !imageDataString.isBangQualifiedEmpty else {
            return .success(.init(
                name: name,
                imageData: nil,
                isPenPalsConversation: isPenPalsConversation,
                lastModifiedDate: lastModifiedDate,
                messageRecipientConsentAcknowledgementData: messageRecipientConsentAcknowledgementData,
                penPalsSharingData: penPalsSharingData,
                requiresConsentFromInitiator: requiesConsentFromInitiator.isBangQualifiedEmpty ? nil : requiesConsentFromInitiator
            ))
        }

        guard let imageData = Data(base64Encoded: imageDataString) else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        return .success(.init(
            name: name,
            imageData: imageData,
            isPenPalsConversation: isPenPalsConversation,
            lastModifiedDate: lastModifiedDate,
            messageRecipientConsentAcknowledgementData: messageRecipientConsentAcknowledgementData,
            penPalsSharingData: penPalsSharingData,
            requiresConsentFromInitiator: requiesConsentFromInitiator.isBangQualifiedEmpty ? nil : requiesConsentFromInitiator
        ))
    }
}
