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

public struct AvatarImageView: View {
    // MARK: - Types

    public enum Configuration {
        case badge(count: Int)
        case singleImage(_ image: UIImage? = nil)
    }

    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.AvatarImageView
    private typealias Floats = AppConstants.CGFloats.AvatarImageView
    private typealias Strings = AppConstants.Strings.AvatarImageView

    // MARK: - Properties

    private let configuration: Configuration
    private let size: CGSize

    // MARK: - Init

    public init(_ configuration: Configuration, size: CGSize? = nil) {
        self.configuration = configuration
        self.size = size ?? .init(width: Floats.frameWidth, height: Floats.frameHeight)
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch configuration {
            case .badge:
                Image(systemName: Strings.badgeImageSystemName)
                    .resizable()
                    .foregroundStyle(Colors.imageForeground)

            case let .singleImage(image):
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Circle())
                } else {
                    Image(systemName: Strings.defaultImageSystemName)
                        .resizable()
                        .foregroundStyle(Colors.imageForeground)
                }
            }
        }
        .font(.system(size: Floats.systemFontSize))
        .frame(width: size.width, height: size.height)
        .cornerRadius(Floats.cornerRadius)
        .overlay {
            switch configuration {
            case let .badge(count):
                badgeView(count)
                    .offset(
                        x: Floats.badgeViewOffsetX,
                        y: Floats.badgeViewOffsetY
                    )

            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func badgeView(_ badgeNumber: Int) -> some View {
        let badgeContentView = Text("\(badgeNumber)")
            .font(.system(size: Floats.badgeViewLabelSystemFontSize).bold())
            .foregroundStyle(Color.titleText)
            .shadow(
                color: Colors.badgeViewLabelShadow,
                radius: Floats.badgeViewShadowRadius
            )
            .frame(
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
