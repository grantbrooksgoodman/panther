//
//  UserInfoBadgeView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A badge displaying a user's language code and regional flag.
///
/// Use ``UserInfoBadgeView`` alongside a user's name to indicate their language and region.
/// The flag is resolved from the user's region code, falling back to their language code;
/// when given an action, the badge becomes a button.
struct UserInfoBadgeView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.UserInfoBadgeView
    private typealias Floats = AppConstants.CGFloats.UserInfoBadgeView

    // MARK: - Properties

    private let action: (() -> Void)?
    private let flagImage: UIImage
    private let user: User

    // MARK: - Init

    /// Creates a user info badge for the given user.
    ///
    /// - Parameters:
    ///   - user: The user the badge describes.
    ///   - action: The action performed when the user taps the badge. Pass `nil` for no
    ///     action. The default is `nil`.
    init(
        _ user: User,
        action: (() -> Void)? = nil
    ) {
        self.user = user
        self.action = action

        if let imageFromRegion = UIImage(named: "\(user.phoneNumber.regionCode.lowercased()).png") {
            flagImage = imageFromRegion
        } else if let imageFromLanguageCode = UIImage(named: "\(user.languageCode.lowercased()).png") {
            flagImage = imageFromLanguageCode
        } else {
            flagImage = UIImage()
        }
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        Rectangle()
            .overlay(contentView, alignment: .center)
            .frame(maxWidth: Floats.bodyMaxWidth, maxHeight: Floats.bodyMaxHeight)
            .foregroundStyle(ThemeService.isDarkModeActive ? Colors.bodyDarkForeground : Colors.bodyLightForeground)
            .roundedCorners(Floats.bodyCornerRadius)
    }

    @ViewBuilder
    private var contentView: some View {
        if let action {
            Button(action: action) {
                labelView
            }
            .buttonStyle(HighPriorityButtonStyle())
        } else {
            labelView
        }
    }

    private var labelView: some View {
        HStack(alignment: .center, spacing: Floats.labelViewHStackSpacing) {
            Components.text(
                user.languageCode.uppercased(),
                font: .systemSemibold(scale: .small),
                isInspectable: true
            )
            .shadow(
                color: Colors.labelViewTextShadow,
                radius: Floats.labelViewTextShadowRadius
            )
            .frame(
                width: Floats.labelViewTextFrameWidth,
                height: Floats.labelViewTextFrameHeight,
                alignment: .center
            )
            .opacity(Floats.labelViewTextOpacity)

            Image(uiImage: flagImage)
                .resizable()
                .frame(
                    width: Floats.labelViewImageFrameWidth,
                    height: Floats.labelViewImageFrameHeight,
                    alignment: .center
                )
                .roundedCorners(Floats.labelViewImageCornerRadius)
        }
    }
}
