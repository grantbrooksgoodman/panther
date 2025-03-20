//
//  ConversationMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public struct ConversationMetadata: Codable, Equatable {
    // MARK: - Properties

    public let name: String
    public let imageData: Data?
    public let isPenPalsConversation: Bool
    public let lastModifiedDate: Date
    public let penPalsSharingData: [PenPalsSharingData]

    // MARK: - Computed Properties

    public var image: UIImage? {
        guard let imageData else { return nil }
        return .init(data: imageData)
    }

    // MARK: - Init

    public init(
        name: String,
        imageData: Data?,
        isPenPalsConversation: Bool,
        lastModifiedDate: Date,
        penPalsSharingData: [PenPalsSharingData]
    ) {
        self.name = name
        self.imageData = imageData
        self.isPenPalsConversation = isPenPalsConversation
        self.lastModifiedDate = lastModifiedDate
        self.penPalsSharingData = penPalsSharingData
    }

    // MARK: - Default Value

    public static func empty(
        userIDs: [String],
        isPenPalsConversation: Bool = false
    ) -> ConversationMetadata {
        .init(
            name: .bangQualifiedEmpty,
            imageData: nil,
            isPenPalsConversation: isPenPalsConversation,
            lastModifiedDate: .init(timeIntervalSince1970: 0),
            penPalsSharingData: userIDs.reduce(into: [PenPalsSharingData]()) { partialResult, userID in
                partialResult.append(.init(userID: userID, isSharingPenPalsData: false))
            }
        )
    }
}
