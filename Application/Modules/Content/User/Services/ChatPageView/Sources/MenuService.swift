//
//  MenuService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 07/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class MenuService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.MenuService
    
    // MARK: - Properties

    public private(set) var isShowingMenu = false

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Set Is Showing Menu

    public func setIsShowingMenu(_ isShowingMenu: Bool) {
        self.isShowingMenu = isShowingMenu
    }

    // MARK: - Configure Menu Gesture Recognizer

    public func configureMenuGestureRecognizer() {
        let longPressGesture: UILongPressGestureRecognizer = .init(target: self, action: #selector(longPressGestureRecognized))
        longPressGesture.delaysTouchesBegan = true
        longPressGesture.minimumPressDuration = Floats.longPressGestureMinimumPressDuration
        viewController.messagesCollectionView.addGestureRecognizer(longPressGesture)
    }

    // MARK: - Menu for Message

    public func menuForMessage(at index: Int) -> UIMenu? {
        guard let messages = viewController.currentConversation?.messages,
              messages.count > index else { return nil }
        let message = messages[index]

        var actions = [UIAction]()

        if !message.hasAudioComponent {
            actions = [
                .init(
                    title: Localized(.copy).wrappedValue,
                    identifier: .init(rawValue: .init(index)),
                    handler: handleAction(_:)
                ),
            ]
        }

        return .init(children: actions)
    }

    // MARK: - Action Handlers

    private func handleCopyAction(_ id: UIAction.Identifier) {
        @Dependency(\.uiPasteboard) var uiPasteboard: UIPasteboard

        guard let index = Int(id.rawValue),
              let messages = viewController.currentConversation?.messages,
              messages.count > index else { return }

        let message = messages[index]
        uiPasteboard.string = message.isFromCurrentUser ? message.translation.input.value() : message.translation.output
    }

    // MARK: - Auxiliary

    private func handleAction(_ action: UIAction) {
        switch action.title {
        case Localized(.copy).wrappedValue:
            handleCopyAction(action.identifier)

        default: ()
        }
    }

    @objc
    private func longPressGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        guard !isShowingMenu else { return }

        let touchPoint = recognizer.location(in: viewController.messagesCollectionView)

        guard let indexPath = viewController.messagesCollectionView.indexPathForItem(at: touchPoint),
              let selectedCell = viewController.messagesCollectionView.cellForItem(at: indexPath) as? MessageContentCell else { return }

        let convertedTouchPoint = viewController.messagesCollectionView.convert(touchPoint, to: selectedCell.messageContainerView)
        guard selectedCell.messageContainerView.bounds.contains(convertedTouchPoint) else { return }

        let editMenuInteraction = UIEditMenuInteraction(delegate: viewController)
        selectedCell.messageContainerView.addInteraction(editMenuInteraction)

        let configuration: UIEditMenuConfiguration = .init(
            identifier: indexPath.section,
            sourcePoint: .init(
                x: convertedTouchPoint.x,
                y: selectedCell.messageContainerView.superview!.frame.minY
            )
        )

        editMenuInteraction.presentEditMenu(with: configuration)
    }
}
