//
//  ContextMenuStyle.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public struct ContextMenuStyle {
    // MARK: - Types

    public struct Preview {
        /* MARK: Properties */

        // CGFloat
        public var bottomMargin: CGFloat
        public var topMargin: CGFloat

        // Other
        public var shadow: ShadowParameters
        public var transform: CGAffineTransform

        /* MARK: Init */

        public init(
            transform: CGAffineTransform = .init(scaleX: 1.2, y: 1.2),
            topMargin: CGFloat = 8,
            bottomMargin: CGFloat = 8,
            shadow: ShadowParameters = .init()
        ) {
            self.transform = transform
            self.topMargin = topMargin
            self.bottomMargin = bottomMargin
            self.shadow = shadow
        }
    }

    // MARK: - Properties

    // AnimationParameters
    public let appearAnimationParameters: AnimationParameters
    public let disappearAnimationParameters: AnimationParameters

    // Other
    public static let `default` = ContextMenuStyle()

    public let blurAlpha: CGFloat
    public let backgroundBlurStyle: UIBlurEffect.Style
    public let backgroundColor: UIColor
    public let menu: MenuView.Style
    public let preview: Preview
    public let windowLevel: UIWindow.Level

    // MARK: - Init

    public init(
        windowLevel: UIWindow.Level = .statusBar - 1,
        backgroundColor: UIColor = .clear,
        backgroundBlurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark,
        blurAlpha: CGFloat = 1,
        appearAnimationParameters: AnimationParameters = .init(),
        disappearAnimationParameters: AnimationParameters = .init(),
        preview: Preview = .init(),
        menu: MenuView.Style = .init()
    ) {
        self.windowLevel = windowLevel
        self.backgroundColor = backgroundColor
        self.backgroundBlurStyle = backgroundBlurStyle
        self.blurAlpha = blurAlpha
        self.appearAnimationParameters = appearAnimationParameters
        self.disappearAnimationParameters = disappearAnimationParameters
        self.preview = preview
        self.menu = menu
    }
}
