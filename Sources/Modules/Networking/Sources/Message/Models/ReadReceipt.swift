//
//  ReadReceipt.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct ReadReceipt: Codable, Equatable {
    // MARK: - Properties

    public let readDate: Date
    public let userID: String

    // MARK: - Init

    public init(userID: String, readDate: Date) {
        self.userID = userID
        self.readDate = readDate
    }
}
