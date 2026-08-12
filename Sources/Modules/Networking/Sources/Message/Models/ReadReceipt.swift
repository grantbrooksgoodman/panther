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

/// A record that a user read a message, and when.
struct ReadReceipt: Codable, Equatable {
    // MARK: - Properties

    /// The date the user read the message.
    let readDate: Date

    /// The identifier of the user who read the message.
    let userID: String

    // MARK: - Init

    /// Creates a read receipt.
    ///
    /// - Parameters:
    ///   - userID: The identifier of the user who read the message.
    ///   - readDate: The date the user read the message.
    init(
        userID: String,
        readDate: Date
    ) {
        self.userID = userID
        self.readDate = readDate
    }
}
