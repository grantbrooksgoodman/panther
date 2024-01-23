//
//  ConversationCellViewData.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public struct ConversationCellViewData: Equatable {
    // MARK: - Properties

    // String
    public let dateLabelText: String
    public let subtitleLabelText: String
    public let titleLabelText: String

    // Other
    public let contactImage: UIImage?
    public let isShowingUnreadIndicator: Bool
    public let otherUser: User?

    // MARK: - Computed Properties

    public static var empty: ConversationCellViewData {
        .init(
            titleLabelText: "",
            subtitleLabelText: "",
            dateLabelText: "",
            contactImage: nil,
            isShowingUnreadIndicator: false,
            otherUser: nil
        )
    }

    // MARK: - Init

    public init(
        titleLabelText: String,
        subtitleLabelText: String,
        dateLabelText: String,
        contactImage: UIImage?,
        isShowingUnreadIndicator: Bool,
        otherUser: User?
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.dateLabelText = dateLabelText
        self.contactImage = contactImage
        self.isShowingUnreadIndicator = isShowingUnreadIndicator
        self.otherUser = otherUser
    }
}
