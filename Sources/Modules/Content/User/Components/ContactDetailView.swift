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

public struct ContactDetailView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ContactDetailView
    private typealias Floats = AppConstants.CGFloats.ContactDetailView
    private typealias Strings = AppConstants.Strings.ContactDetailView

    // MARK: - Properties

    // String
    private let subtitleLabelText: String?
    private let titleLabelText: String

    // Other
    private let image: UIImage?

    // MARK: - Init

    public init(
        titleLabelText: String,
        subtitleLabelText: String?,
        image: UIImage?
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.image = image
    }

    // MARK: - View

    public var body: some View {
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
            UIApplication.v26FeaturesEnabled,
            { $0.glassEffect(padding: Floats.glassEffectPadding) },
            else: {
                $0
                    .background(ThemeService.isDarkModeActive ? Colors.darkBackground : Colors.lightBackground)
                    .cornerRadius(Floats.cornerRadius)
            }
        )
    }
}
