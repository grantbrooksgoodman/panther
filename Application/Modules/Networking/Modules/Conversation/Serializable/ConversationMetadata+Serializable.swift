//
//  ConversationMetadata+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

extension ConversationMetadata: Serializable {
    // MARK: - Type Aliases

    public typealias T = ConversationMetadata
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case name
        case imageData
        case lastModifiedDate = "lastModified"
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.name.rawValue: name,
            Keys.imageData.rawValue: imageData?.base64EncodedString() ?? .bangQualifiedEmpty,
            Keys.lastModifiedDate.rawValue: dateFormatter.string(from: lastModifiedDate),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.name.rawValue] as? String != nil,
              data[Keys.imageData.rawValue] as? String != nil,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              dateFormatter.date(from: lastModifiedDateString) != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<ConversationMetadata, Exception> {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        guard let name = data[Keys.name.rawValue] as? String,
              let imageDataString = data[Keys.imageData.rawValue] as? String,
              let lastModifiedDateString = data[Keys.lastModifiedDate.rawValue] as? String,
              let lastModifiedDate = dateFormatter.date(from: lastModifiedDateString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        guard !imageDataString.isBangQualifiedEmpty else {
            return .success(.init(name: name, imageData: nil, lastModifiedDate: lastModifiedDate))
        }

        guard let imageData = Data(base64Encoded: imageDataString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        return .success(.init(name: name, imageData: imageData, lastModifiedDate: lastModifiedDate))
    }
}
