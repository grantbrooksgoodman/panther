//
//  PenPalsSharingData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct PenPalsSharingData: Codable, Equatable {
    // MARK: - Properties

    public let isSharingPenPalsData: Bool
    public let userID: String

    // MARK: - Init

    public init(
        userID: String,
        isSharingPenPalsData: Bool
    ) {
        self.userID = userID
        self.isSharingPenPalsData = isSharingPenPalsData
    }
}
