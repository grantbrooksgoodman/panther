//
//  ReactionsView.swift
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

public final class ReactionsViewController: UIViewController {
    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.contextMenu) private var contextMenuService: ContextMenuService?

    // MARK: - Properties

    public var selectedReaction: String?

    private let reactions: [String] = Reaction.Style.orderedCases.map(\.emojiValue)

    // MARK: - Computed Properties

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        return stackView
    }()

    // MARK: - View Did Load

    override public func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        setUpReactions()
        updatePreferredContentSize()
    }

    // MARK: - Reaction Selection

    public func deselectAllReactions() {
        stackView.subviews.forEach { $0.backgroundColor = .disabled }
    }

    public func markSelected(_ emoji: String) {
        stackView
            .subviews
            .compactMap { $0 as? UIButton }
            .first(where: { $0.titleLabel?.text == emoji })?
            .backgroundColor = .systemBlue
    }

    // MARK: - Auxiliary

    private func buildReactionButton(with emoji: String) -> UIButton {
        let reactionButton = UIButton(type: .system)

        reactionButton.setTitle(emoji, for: .normal)
        reactionButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        reactionButton.backgroundColor = .disabled

        reactionButton.layer.cornerRadius = 17.5
        reactionButton.layer.masksToBounds = true
        reactionButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            reactionButton.widthAnchor.constraint(equalToConstant: 35),
            reactionButton.heightAnchor.constraint(equalToConstant: 35),
        ])

        if let contextMenuService {
            reactionButton.addTarget(
                contextMenuService,
                action: #selector(contextMenuService.reactToSelectedMessage(_:)),
                for: .touchUpInside
            )
        }

        return reactionButton
    }

    private func setUpReactions() {
        reactions.forEach { reaction in
            let button = buildReactionButton(with: reaction)
            stackView.addArrangedSubview(button)
        }
    }

    private func setUpView() {
        view.alpha = 0.8
        view.backgroundColor = .clear

        view.layer.cornerRadius = 5
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false

        stackView.alpha = 0.8
        stackView.backgroundColor = .disabled
        stackView.layer.cornerRadius = 17.5

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: 0),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
    }

    private func updatePreferredContentSize() {
        let buttonHeight: CGFloat = 35
        preferredContentSize = CGSize(width: stackView.frame.width, height: buttonHeight)
    }
}
