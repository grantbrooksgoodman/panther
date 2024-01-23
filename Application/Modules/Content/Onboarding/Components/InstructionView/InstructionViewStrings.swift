//
//  InstructionViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct InstructionViewStrings: Equatable {
    // MARK: - Properties

    public let subtitleLabelText: String
    public let titleLabelText: String

    // MARK: - Computed Properties

    public static var empty: InstructionViewStrings {
        .init(titleLabelText: "", subtitleLabelText: "")
    }

    // MARK: - Init

    public init(titleLabelText: String, subtitleLabelText: String) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
    }
}
