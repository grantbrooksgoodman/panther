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

struct ContextMenuStyle {
    // MARK: - Types

    struct Preview {
        /* MARK: Properties */

        // CGFloat
        var bottomMargin: CGFloat
        var topMargin: CGFloat

        // Other
        var shadow: ShadowParameters
        var transform: CGAffineTransform

        /* MARK: Init */

        init(
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
    let appearAnimationParameters: AnimationParameters
    let disappearAnimationParameters: AnimationParameters

    // Other
    static let `default` = ContextMenuStyle()

    let blurAlpha: CGFloat
    let backgroundBlurStyle: UIBlurEffect.Style
    let backgroundColor: UIColor
    let menu: MenuView.Style
    let preview: Preview
    let windowLevel: UIWindow.Level

    // MARK: - Init

    init(
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
