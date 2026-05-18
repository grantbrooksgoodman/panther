//
//  ContextMenuInteractor.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AudioToolbox
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

@MainActor
final class ContextMenuInteractor {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.contextMenu) private var contextMenuService: ContextMenuService?
    @Dependency(\.commonServices.haptics) private var hapticsService: HapticsService
    @Dependency(\.mainBundle) private var mainBundle: Bundle

    // MARK: - Properties

    static let kGesturePressDuration = TimeInterval(0.22)
    static let shared = ContextMenuInteractor()

    let interactions = NSMapTable<UIView, Interaction>(
        keyOptions: .weakMemory,
        valueOptions: .strongMemory
    )

    var contextMenuViewController: ContextMenuViewController?
    weak var viewOriginalWindow: UIWindow?

    private var isShowing = false

    // MARK: - Computed Properties

    let window: UIWindow = {
        let window = UIWindow()
        window.backgroundColor = .clear
        return window
    }()

    // MARK: - Dismiss Context Menu

    func dismissContextMenu(
        view: UIView,
        completion: (() -> Void)?
    ) {
        dismissContextMenu(
            interaction: interactions.object(forKey: view),
            completion: completion
        )
    }

    // MARK: - Interaction Handlers

    // swiftlint:disable:next function_parameter_count
    func addInteraction(
        on view: UIView,
        targetedPreviewProvider: @escaping TargetedPreviewProvider,
        menuConfigurationProvider: @escaping MenuConfigurationProvider,
        style: ContextMenuStyle,
        onInteractionBegan: (() -> Void)?,
        onInteractionEnded: (() -> Void)?
    ) {
        removeInteraction(from: view)

        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(beginInteraction(_:)))
        gesture.minimumPressDuration = ContextMenuInteractor.kGesturePressDuration

        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(gesture)

        interactions.setObject(.init(
            gesture: gesture,
            targetedPreviewProvider: targetedPreviewProvider,
            menuConfigurationProvider: menuConfigurationProvider,
            style: style,
            onInteractionBegan: onInteractionBegan,
            onInteractionEnded: onInteractionEnded
        ), forKey: view)
    }

    @objc
    func beginInteraction(
        _ sender: UIGestureRecognizer
    ) {
        guard ContextMenuInteraction.canBegin,
              sender.state == .began,
              let view = sender.view,
              let interaction = interactions.object(forKey: view) else { return }

        contextMenuService?.interaction.setIsPresentingContextMenu(true)
        interaction.onInteractionBeganEffect?()

        guard contextMenuService?.actionHandler.speakingMessage == nil else {
            Task.delayed(by: .milliseconds(10)) { @MainActor in
                showContextMenu(on: view, interaction: interaction)
            }
            return
        }

        showContextMenu(on: view, interaction: interaction)
    }

    func removeInteraction(
        from view: UIView
    ) {
        guard let interaction = interactions.object(forKey: view) else { return }
        view.removeGestureRecognizer(interaction.gesture)
        interactions.removeObject(forKey: view)
    }

    // MARK: - Context Menu Handlers

    func dismissContextMenu(
        interaction: Interaction?,
        completion: (() -> Void)?
    ) {
        contextMenuViewController?.disappearAnimation { [weak self] in
            interaction?.gesture.isEnabled = true
            self?.restoreWindow()
            self?.contextMenuService?.interaction.setIsPresentingContextMenu(false)
            interaction?.onInteractionEndedEffect?()
            completion?()
        }
    }

    func dismissCurrentContextMenu(
        completion: (() -> Void)? = nil
    ) {
        if let contextMenuInteractionService = contextMenuService?.interaction {
            guard contextMenuInteractionService.isPresentingContextMenu else { return }
        }

        guard let contextMenuViewController else {
            completion?()
            return
        }

        dismissContextMenu(
            interaction: contextMenuViewController.interaction,
            completion: completion
        )
    }

    // MARK: - Auxiliary

    private func playSelectionSound() {
        guard let url = mainBundle.url(
            forResource: "Selection",
            withExtension: "caf"
        ) else { return }

        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(
            url as CFURL,
            &soundID
        )

        AudioServicesPlaySystemSound(soundID)
    }

    private func restoreWindow() {
        window.rootViewController = nil
        window.isHidden = true
        window.windowScene = nil
    }

    private func showContextMenu(
        on view: UIView,
        interaction: Interaction
    ) {
        guard !isShowing else { return }
        isShowing = true

        interaction.gesture.isEnabled = false
        viewOriginalWindow = view.window

        let targetedPreview = interaction.targetedPreviewProvider(view) ?? .init(view: view)
        let contextMenuController = ContextMenuViewController(
            interaction: interaction,
            view: view,
            targetedPreview: targetedPreview,
            baseFrameInScreen: targetedPreview.view.convert(targetedPreview.view.bounds, to: nil),
            delegate: self
        )
        contextMenuViewController = contextMenuController
        contextMenuController.view.frame = window.bounds

        window.overrideUserInterfaceStyle = Application.isInPrevaricationMode ? .light : ThemeService.currentTheme.style
        window.windowLevel = interaction.style.windowLevel
        window.windowScene = viewOriginalWindow?.windowScene
        window.rootViewController = contextMenuController

        playSelectionSound()
        hapticsService.generateFeedback(.heavy)

        window.makeKeyAndVisible()
        contextMenuController.appearAnimation()

        Task.delayed(by: .milliseconds(
            (contextMenuController.style.appearAnimationParameters.duration * 1000)
                + 50
        )) { @MainActor in
            self.isShowing = false
        }
    }
}
