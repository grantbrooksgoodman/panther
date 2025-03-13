//
//  ContactPairCellView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct ContactPairCellView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ContactPairCellView

    // MARK: - Properties

    // String
    @Localized(.blocked) private var blockedLabelText: String
    @Localized(.myAccount) private var myAccountLabelText: String

    // Other
    private let action: (() -> Void)?
    private let contactPair: ContactPair

    // MARK: - Computed Properties

    private var isSelectionEnabled: Bool {
        !(contactPair.containsBlockedUser || contactPair.containsCurrentUser || contactPair.isSelected)
    }

    // MARK: - Init

    public init(contactPair: ContactPair, action: (() -> Void)? = nil) {
        self.contactPair = contactPair
        self.action = action
    }

    // MARK: - View

    public var body: some View {
        if let action {
            Button {
                action()
            } label: {
                labelView
            }
            .disabled(!isSelectionEnabled)
        } else {
            labelView
        }
    }

    private var labelView: some View {
        let foregroundColor = isSelectionEnabled ? .titleText : Color.disabled

        return HStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: Floats.hStackSpacing) {
                if !contactPair.contact.firstName.isBlank {
                    Components.text(
                        contactPair.contact.firstName,
                        foregroundColor: foregroundColor
                    )
                }

                Components.text(
                    contactPair.contact.lastName,
                    font: .systemSemibold,
                    foregroundColor: foregroundColor
                )

                if contactPair.containsBlockedUser {
                    Components.text(
                        "(\(blockedLabelText))",
                        foregroundColor: foregroundColor
                    )
                }

                if contactPair.containsCurrentUser {
                    Components.text(
                        myAccountLabelText,
                        foregroundColor: foregroundColor
                    )
                }
            }

            Spacer()

            if let user = contactPair.users.first {
                UserInfoBadgeView(user)
            }
        }
    }
}
