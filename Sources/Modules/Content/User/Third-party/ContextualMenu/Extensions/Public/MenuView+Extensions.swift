//
//  MenuView+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension MenuView: ContextMenuAnimatable {
    func appearAnimation(completion: (() -> Void)? = nil) {
        applyTransform(
            scale: style.disappearedScalingValue,
            anchorPoint: anchorPointAlignment == .leading ? .zero : .init(x: 1, y: 0)
        )
        alpha = 0
        UIView.animate(
            withDuration: style.disappearAnimationParameters.duration,
            delay: 0,
            usingSpringWithDamping: style.disappearAnimationParameters.damping,
            initialSpringVelocity: style.disappearAnimationParameters.initialSpringVelocity,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                guard let self else { return }
                alpha = 1
                applyTransform(
                    scale: 1,
                    anchorPoint: anchorPointAlignment == .leading ? .zero : .init(x: 1, y: 0)
                )
            },
            completion: { _ in
                completion?()
            }
        )
    }

    func disappearAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: style.disappearAnimationParameters.duration,
            delay: 0,
            usingSpringWithDamping: style.disappearAnimationParameters.damping,
            initialSpringVelocity: style.disappearAnimationParameters.initialSpringVelocity,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                guard let self else { return }
                alpha = 0
                applyTransform(
                    scale: style.disappearedScalingValue,
                    anchorPoint: anchorPointAlignment == .leading ? .zero : .init(x: 1, y: 0)
                )
            },
            completion: { _ in
                completion?()
            }
        )
    }
}

extension MenuView: @preconcurrency MenuElementViewDelegate {
    func menuElementViewTapped(menuElementView: MenuElementView) {
        delegate?.dismissMenuView(menuView: self, uponTapping: menuElementView.element)
    }
}
