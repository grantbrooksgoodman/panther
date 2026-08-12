//
//  ContactDetailView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A row displaying a contact's avatar, title, and optional subtitle.
///
/// Use ``ContactDetailView`` to summarize a contact in a list. When a subtitle is provided, a
/// chevron indicates that the row leads to further detail.
struct ContactDetailView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ContactDetailView
    private typealias Floats = AppConstants.CGFloats.ContactDetailView
    private typealias Strings = AppConstants.Strings.ContactDetailView

    // MARK: - Properties

    private let image: UIImage?
    private let subtitleLabelText: String?
    private let titleLabelText: String

    // MARK: - Init

    /// Creates a contact detail row.
    ///
    /// - Parameters:
    ///   - titleLabelText: The text the title label displays.
    ///   - subtitleLabelText: The text the subtitle label displays. Pass `nil` to omit the
    ///     subtitle and chevron.
    ///   - image: The avatar image to display, or `nil` to show a placeholder symbol.
    init(
        titleLabelText: String,
        subtitleLabelText: String?,
        image: UIImage?
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.image = image
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        HStack {
            AvatarImageView(image)
                .padding(.trailing, Floats.avatarImageViewTrailingPadding)

            VStack(alignment: .leading) {
                Components.text(
                    titleLabelText,
                    font: .systemSemibold
                )
                .padding(.bottom, 0)

                if let subtitleLabelText,
                   !subtitleLabelText.isBlank {
                    Components.text(
                        subtitleLabelText,
                        font: .system(scale: .small)
                    )
                }
            }

            Spacer()

            if subtitleLabelText != nil {
                Components.symbol(
                    Strings.chevronImageSystemName,
                    foregroundColor: .subtitleText,
                    weight: .semibold,
                    usesIntrinsicSize: false
                )
                .frame(
                    maxWidth: Floats.chevronImageFrameMaxWidth,
                    maxHeight: Floats.chevronImageFrameMaxHeight
                )
            }
        }
        .padding()
        .if(
            UIApplication.isFullyV26Compatible
        ) {
            $0.glassEffect(padding: Floats.glassEffectPadding)
        } else: {
            $0
                .background(ThemeService.isDarkModeActive ? Colors.darkBackground : Colors.lightBackground)
                .cornerRadius(Floats.cornerRadius)
        }
    }
}
