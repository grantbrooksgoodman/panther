//
//  ReactionsViewController.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/* 3rd-party */
import MessageKit

final class ReactionsViewController: UIViewController {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ReactionsViewController
    private typealias Floats = AppConstants.CGFloats.ReactionsViewController

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.contextMenu?.interaction) private var contextMenuInteractionService: ContextMenuInteractionService?

    // MARK: - Properties

    private let reactions: [String] = Reaction.Style.orderedCases.map(\.emojiValue)

    // MARK: - Computed Properties

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = Floats.stackViewSpacing
        return stackView
    }()

    // MARK: - View Did Load

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        setUpReactions()
        updatePreferredContentSize()
    }

    // MARK: - Reaction Selection

    func deselectAllReactions() {
        stackView.subviews.forEach {
            $0.backgroundColor = Colors.reactionButtonBackground
        }
    }

    func markSelected(_ reactionStyle: Reaction.Style) {
        stackView
            .subviews
            .compactMap { $0 as? UIButton }
            .first(where: { $0.titleLabel?.text == reactionStyle.emojiValue })?
            .backgroundColor = UIColor(reactionStyle.squareIconBackgroundColor)
    }

    // MARK: - Auxiliary

    private func buildReactionButton(with emoji: String) -> UIButton {
        let reactionButton = UIButton(type: .system)

        reactionButton.setTitle(emoji, for: .normal)
        reactionButton.titleLabel?.font = UIFont.systemFont(
            ofSize: Floats.reactionButtonTitleLabelSystemFontSize
        )
        reactionButton.backgroundColor = Colors.reactionButtonBackground

        reactionButton.layer.cornerRadius = Floats.subviewLayerCornerRadius
        reactionButton.layer.masksToBounds = true
        reactionButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            reactionButton.widthAnchor.constraint(
                equalToConstant: Floats.reactionButtonHeight
            ),
            reactionButton.heightAnchor.constraint(
                equalToConstant: Floats.reactionButtonHeight
            ),
        ])

        if let contextMenuInteractionService {
            reactionButton.addTarget(
                contextMenuInteractionService,
                action: #selector(contextMenuInteractionService.reactToSelectedMessage(_:)),
                for: .touchUpInside
            )
        }

        return reactionButton
    }

    private func setUpReactions() {
        reactions.forEach { reaction in
            stackView.addArrangedSubview(
                buildReactionButton(with: reaction)
            )
        }
    }

    private func setUpView() {
        view.alpha = Floats.viewAlpha
        view.backgroundColor = .clear

        view.layer.cornerRadius = Floats.superviewLayerCornerRadius
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false

        stackView.alpha = Floats.viewAlpha
        stackView.backgroundColor = Colors.reactionButtonBackground
        stackView.layer.cornerRadius = Floats.subviewLayerCornerRadius

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            stackView.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 0
            ),
            stackView.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: Floats.stackViewLeadingAnchorConstraintConstant
            ),
            stackView.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: 0
            ),
            stackView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: 0
            ),
        ])
    }

    private func updatePreferredContentSize() {
        preferredContentSize = .init(
            width: stackView.frame.width,
            height: Floats.reactionButtonHeight
        )
    }
}
