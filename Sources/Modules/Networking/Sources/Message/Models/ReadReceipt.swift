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

struct ReadReceipt: Codable, Equatable {
    // MARK: - Properties

    let readDate: Date
    let userID: String

    // MARK: - Init

    init(userID: String, readDate: Date) {
        self.userID = userID
        self.readDate = readDate
    }
}
