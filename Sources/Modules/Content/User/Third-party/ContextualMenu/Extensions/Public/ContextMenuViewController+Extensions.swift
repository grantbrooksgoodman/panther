//
//  ContextMenuViewController+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension ContextMenuViewController: ContextMenuAnimatable {
    func appearAnimation(completion: (() -> Void)? = nil) {
        NSLayoutConstraint.activate(constraintsAlteringPreviewPosition)
        view.setNeedsLayout()

        previewRendering.layer.applyShadow(style.preview.shadow, overrideOpacity: 0)
        previewRendering.layer.animate(
            keyPath: \.shadowOpacity,
            toValue: style.preview.shadow.opacity,
            duration: style.appearAnimationParameters.duration
        )
        menuView?.appearAnimation()

        if let animatableAccessoryView {
            animatableAccessoryView.appearAnimation()
        } else {
            accessoryView?.alpha = 0
        }

        UIView.animate(
            withDuration: style.appearAnimationParameters.duration,
            delay: 0,
            usingSpringWithDamping: style.appearAnimationParameters.damping,
            initialSpringVelocity: style.appearAnimationParameters.initialSpringVelocity,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                guard let self else { return }
                view.layoutIfNeeded()
                backgroundBlur.alpha = style.blurAlpha
                previewRendering.transform = style.preview.transform

                if animatableAccessoryView == nil {
                    // Perform a default fadin animation if needed
                    accessoryView?.alpha = 1
                }
            },
            completion: { _ in completion?() }
        )
    }

    func disappearAnimation(completion: (() -> Void)? = nil) {
        NSLayoutConstraint.deactivate(constraintsAlteringPreviewPosition)
        view.setNeedsLayout()

        previewRendering.layer.animate(
            keyPath: \.shadowOpacity,
            toValue: 0,
            duration: style.appearAnimationParameters.duration
        )
        menuView?.disappearAnimation()
        animatableAccessoryView?.disappearAnimation()

        UIView.animate(
            withDuration: style.disappearAnimationParameters.duration,
            delay: 0,
            usingSpringWithDamping: style.disappearAnimationParameters.damping,
            initialSpringVelocity: style.disappearAnimationParameters.initialSpringVelocity,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                guard let self else { return }
                view.layoutIfNeeded()
                backgroundBlur.alpha = 0
                previewRendering.transform = .identity

                if animatableAccessoryView == nil {
                    // Perform a default fadout animation if needed
                    accessoryView?.alpha = 0
                }
            },
            completion: { [weak self] _ in
                self?.targetedPreview?.view.alpha = 1

                // targetedPreview might be retaining views. Nullifying it to break any potential retain cycle
                self?.targetedPreview = nil
                completion?()
            }
        )
    }
}

extension ContextMenuViewController: MenuViewDelegate {
    func dismissMenuView(menuView: MenuView, uponTapping menuElement: MenuElement) {
        delegate?.dismissContextMenuViewController(self, interaction: interaction, uponTapping: menuElement)
    }
}

extension ContextMenuViewController {
    // MARK: - Types

    struct FixedAndAnimatableConstraints {
        /* MARK: Properties */

        let animatable: [NSLayoutConstraint]
        static let empty: FixedAndAnimatableConstraints = .init(fixed: [], animatable: [])
        let fixed: [NSLayoutConstraint]

        /* MARK: Init */

        init(fixed: [NSLayoutConstraint], animatable: [NSLayoutConstraint]) {
            self.fixed = fixed
            self.animatable = animatable
        }
    }

    // MARK: - Methods

    /// Returns alignment of menu & accessoryView relative to the preview.
    /// Items are aligned to leading if the preview is centered on the leading part of the screen, otherwise trailing
    func menuAndAccessoryViewAlignment() -> Alignment {
        baseFrameInScreen.midX > view.bounds.midX ? .trailing : .leading
    }

    @objc
    func onTouchUpInsideBackground(_ sender: Any?) {
        delegate?.dismissContextMenuViewController(self, interaction: interaction, uponTapping: nil)
    }
}
