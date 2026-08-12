//
//  AvatarImageView.swift
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

/// A circular avatar image with an optional participant count badge.
///
/// Use ``AvatarImageView`` to display a contact's or conversation's thumbnail. When no image
/// is available – or the view is redacted – a placeholder symbol is shown instead. Badge
/// counts greater than one appear as an overlaid count; pass `-1` to show the group
/// placeholder symbol without a count.
struct AvatarImageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.AvatarImageView
    private typealias Floats = AppConstants.CGFloats.AvatarImageView
    private typealias Strings = AppConstants.Strings.AvatarImageView

    // MARK: - Properties

    private let badgeCount: Int
    private let image: UIImage?
    private let size: CGSize

    @Environment(\.redactionReasons) private var redactionReasons

    // MARK: - Init

    /// Creates an avatar image view.
    ///
    /// - Parameters:
    ///   - image: The image to display, or `nil` to show a placeholder symbol.
    ///   - badgeCount: The number of participants the badge displays. Values greater than one
    ///     show the badge; pass `-1` to show the group placeholder symbol without a count.
    ///     The default is `0`.
    ///   - size: The size of the view. Pass `nil` to use the default size.
    init(
        _ image: UIImage?,
        badgeCount: Int = 0,
        size: CGSize? = nil
    ) {
        self.image = image
        self.badgeCount = badgeCount
        self.size = size ?? .init(width: Floats.frameWidth, height: Floats.frameHeight)
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        Group {
            if !redactionReasons.isEmpty {
                Components.symbol(
                    Strings.defaultImageSystemName,
                    foregroundColor: Colors.imageForeground,
                    usesIntrinsicSize: false
                )
                .clipShape(Circle())
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Components.symbol(
                    (badgeCount < 2 && badgeCount != -1) ? Strings.defaultImageSystemName : Strings.badgeImageSystemName,
                    foregroundColor: Colors.imageForeground,
                    usesIntrinsicSize: false
                )
                .clipShape(Circle())
            }
        }
        .font(.system(size: Floats.systemFontSize))
        .frame(width: size.width, height: size.height)
        .cornerRadius(Floats.cornerRadius)
        .if(badgeCount > 1) {
            $0.overlay {
                badgeView
                    .offset(
                        x: Floats.badgeViewOffsetX,
                        y: Floats.badgeViewOffsetY
                    )
            }
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        let badgeContentView = Components.text(
            "\(badgeCount)",
            font: .systemSemibold(scale: .custom(Floats.badgeViewLabelSystemFontSize))
        ).shadow(
            color: Colors.badgeViewLabelShadow,
            radius: Floats.badgeViewShadowRadius
        ).frame(
            width: Floats.badgeViewWidth,
            height: Floats.badgeViewHeight,
            alignment: .center
        )

        Circle()
            .overlay(badgeContentView, alignment: .center)
            .frame(maxWidth: Floats.badgeViewWidth, maxHeight: Floats.badgeViewHeight)
            .foregroundStyle(ThemeService.isDarkModeActive ? Colors.badgeViewDarkForeground : Colors.badgeViewLightForeground)
            .roundedCorners(Floats.badgeViewCornerRadius)
    }
}
