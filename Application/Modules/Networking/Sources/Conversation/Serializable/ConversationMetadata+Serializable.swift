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

    public typealias T = ConversationMetadata
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case name
        case imageData
        case isPenPalsConversation
        case lastModifiedDate = "lastModified"
        case penPalsSharingData = "isSharingPenPalsData"
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.name.rawValue: name,
            Keys.imageData.rawValue: imageData?.base64EncodedString() ?? .bangQualifiedEmpty,
            Keys.isPenPalsConversation.rawValue: isPenPalsConversation,
            Keys.lastModifiedDate.rawValue: dateFormatter.string(from: lastModifiedDate),
            Keys.penPalsSharingData.rawValue: penPalsSharingData.map(\.encoded),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.name.rawValue] is String,
              data[Keys.imageData.rawValue] is String,
              data[Keys.isPenPalsConversation.rawValue] is Bool,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              dateFormatter.date(from: lastModifiedDateString) != nil,
              let encodedPenPalsSharingData = data[Keys.penPalsSharingData.rawValue] as? [String],
              encodedPenPalsSharingData.allSatisfy({ PenPalsSharingData.canDecode(from: $0) }) else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<ConversationMetadata, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard let name = data[Keys.name.rawValue] as? String,
              let imageDataString = data[Keys.imageData.rawValue] as? String,
              let isPenPalsConversation = data[Keys.isPenPalsConversation.rawValue] as? Bool,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              let lastModifiedDate = dateFormatter.date(from: lastModifiedDateString),
              let encodedPenPalsSharingData = data[Keys.penPalsSharingData.rawValue] as? [String] else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

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

        guard !penPalsSharingData.isEmpty,
              penPalsSharingData.count == encodedPenPalsSharingData.count else {
            return .failure(.init("Mismatched ratio returned.", metadata: [self, #file, #function, #line]))
        }

        guard !imageDataString.isBangQualifiedEmpty else {
            return .success(.init(
                name: name,
                imageData: nil,
                isPenPalsConversation: isPenPalsConversation,
                lastModifiedDate: lastModifiedDate,
                penPalsSharingData: penPalsSharingData
            ))
        }

        guard let imageData = Data(base64Encoded: imageDataString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        return .success(.init(
            name: name,
            imageData: imageData,
            isPenPalsConversation: isPenPalsConversation,
            lastModifiedDate: lastModifiedDate,
            penPalsSharingData: penPalsSharingData
        ))
    }
}
