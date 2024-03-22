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
    public let lastModifiedDate: Date

    // MARK: - Computed Properties

    public static var empty: ConversationMetadata {
        .init(name: .bangQualifiedEmpty, imageData: nil, lastModifiedDate: .init(timeIntervalSince1970: 0))
    }

    public var image: UIImage? {
        guard let imageData else { return nil }
        return .init(data: imageData)
    }

    // MARK: - Init

    public init(
        name: String,
        imageData: Data?,
        lastModifiedDate: Date
    ) {
        self.name = name
        self.imageData = imageData
        self.lastModifiedDate = lastModifiedDate
    }
}
