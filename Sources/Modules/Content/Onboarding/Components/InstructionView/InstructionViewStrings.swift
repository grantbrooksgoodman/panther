//
//  InstructionViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct InstructionViewStrings: Equatable {
    // MARK: - Properties

    static let empty: InstructionViewStrings = .init(titleLabelText: "", subtitleLabelText: "")

    let subtitleLabelText: String
    let titleLabelText: String

    // MARK: - Init

    init(titleLabelText: String, subtitleLabelText: String) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
    }
}
