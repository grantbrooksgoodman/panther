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

public struct UserInfoBadgeView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.UserInfoBadgeView
    private typealias Floats = AppConstants.CGFloats.UserInfoBadgeView

    // MARK: - Properties

    private let action: (() -> Void)?
    private let flagImage: UIImage
    private let user: User

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    // MARK: - Init

    public init(_ user: User, action: (() -> Void)? = nil) {
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

    public var body: some View {
        Rectangle()
            .overlay(contentView, alignment: .center)
            .frame(maxWidth: Floats.bodyMaxWidth, maxHeight: Floats.bodyMaxHeight)
            .foregroundStyle(colorScheme == .dark ? Colors.bodyDarkForeground : Colors.bodyLightForeground)
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
            Text(user.languageCode.uppercased())
                .font(.system(size: Floats.labelViewTextSystemFontSize).bold())
                .foregroundStyle(Color.titleText)
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
