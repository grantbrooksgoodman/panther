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

        var bottomMargin: CGFloat
        var shadow: ShadowParameters
        var topMargin: CGFloat
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

    @MainActor
    static let `default` = ContextMenuStyle()

    let appearAnimationParameters: AnimationParameters
    let backgroundBlurStyle: UIBlurEffect.Style
    let backgroundColor: UIColor
    let blurAlpha: CGFloat
    let disappearAnimationParameters: AnimationParameters
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
