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

/// A horizontal strip of emoji reaction buttons for the selected message.
///
/// ``ReactionsViewController`` appears alongside a message's context menu. Tapping a reaction
/// forwards the selection to the context menu interaction service; use ``markSelected(_:)``
/// and ``deselectAllReactions()`` to reflect the current selection.
///
/// The view controller also follows the long-press gesture that
/// presents the menu, as well as any touch that begins on the strip
/// once the menu appears: dragging left or right across the strip
/// highlights each reaction in turn, and releasing over a reaction
/// applies it as though it were tapped.
final class ReactionsViewController: UIViewController, ContextMenuHighlightable {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ReactionsViewController
    private typealias Floats = AppConstants.CGFloats.ReactionsViewController

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService.contextMenu?.interaction) private var contextMenuInteractionService: ContextMenuInteractionService?
    @Dependency(\.commonServices.haptics) private var hapticsService: HapticsService

    // MARK: - Properties

    private let reactions: [String] = Reaction.Style.orderedCases.map(\.emojiValue)

    private var highlightedReactionStyle: Reaction.Style?
    private var selectedReactionStyle: Reaction.Style?

    // MARK: - Computed Properties

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = Floats.stackViewSpacing
        return stackView
    }()

    private var reactionButtons: [UIButton] {
        stackView.arrangedSubviews.compactMap { $0 as? UIButton }
    }

    // MARK: - View Did Load

    /// Configures the reaction strip and its preferred content size after the view loads.
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        setUpReactions()
        updatePreferredContentSize()
    }

    // MARK: - ContextMenuHighlightable Conformance

    /// Highlights the reaction at the given point with its selected
    /// background, in place of the current selection.
    ///
    /// The context menu calls this method as a touch it tracks moves,
    /// whether that touch is the long-press gesture that presents the
    /// menu or one that begins on the strip once the menu appears.
    /// Moving directly from one reaction to another generates
    /// selection haptic feedback. Each reaction's hit area extends
    /// halfway into the spacing beside it, so the highlight never
    /// clears between adjacent reactions.
    ///
    /// - Parameter point: A point in the coordinate space of the view
    ///   controller's view.
    func highlightElement(at point: CGPoint) {
        guard view.isUserInteractionEnabled else { return }
        let reactionStyle = reactionButton(at: point).flatMap {
            self.reactionStyle(for: $0)
        }

        guard reactionStyle != highlightedReactionStyle else { return }
        if highlightedReactionStyle != nil,
           reactionStyle != nil {
            hapticsService.generateFeedback(.selection)
            hapticsService.prepare(.selection)
        }

        highlightedReactionStyle = reactionStyle
        updateReactionButtonBackgrounds()
    }

    /// Applies the reaction at the given point to the message the
    /// context menu targets.
    ///
    /// The reaction remains highlighted while the context menu
    /// dismisses.
    ///
    /// - Parameter point: A point in the coordinate space of the view
    ///   controller's view.
    ///
    /// - Returns: `true` if a reaction exists at `point` and the
    ///   view accepts user interaction; otherwise, `false`.
    func selectElement(at point: CGPoint) -> Bool {
        guard view.isUserInteractionEnabled,
              let reactionButton = reactionButton(at: point),
              let contextMenuInteractionService else { return false }

        contextMenuInteractionService.reactToSelectedMessage(reactionButton)
        return true
    }

    /// Clears the highlighted reaction, restoring the background of
    /// the reaction marked as selected.
    func unhighlightAllElements() {
        highlightedReactionStyle = nil
        updateReactionButtonBackgrounds()
    }

    // MARK: - Reaction Selection

    /// Restores every reaction button to its unselected background.
    func deselectAllReactions() {
        highlightedReactionStyle = nil
        selectedReactionStyle = nil
        updateReactionButtonBackgrounds()
    }

    /// Highlights the button for the given reaction style with its selected background.
    ///
    /// While a touch highlights a reaction, that reaction's
    /// background takes precedence until the highlight clears.
    ///
    /// - Parameter reactionStyle: The reaction style to mark as selected.
    func markSelected(_ reactionStyle: Reaction.Style) {
        selectedReactionStyle = reactionStyle
        updateReactionButtonBackgrounds()
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

    private func reactionButton(at point: CGPoint) -> UIButton? {
        let pointInStackView = stackView.convert(
            point,
            from: view
        )

        return reactionButtons.first {
            $0.frame
                .insetBy(dx: -stackView.spacing / 2, dy: 0)
                .contains(pointInStackView)
        }
    }

    private func reactionStyle(for reactionButton: UIButton) -> Reaction.Style? {
        guard let emojiValue = reactionButton.titleLabel?.text else { return nil }
        return .init(emojiValue: emojiValue)
    }

    private func setUpReactions() {
        for reaction in reactions {
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

    private func updateReactionButtonBackgrounds() {
        let displayedReactionStyle = highlightedReactionStyle ?? selectedReactionStyle
        for reactionButton in reactionButtons {
            if let reactionStyle = reactionStyle(for: reactionButton),
               reactionStyle == displayedReactionStyle {
                reactionButton.backgroundColor = UIColor(
                    reactionStyle.squareIconBackgroundColor
                )
            } else {
                reactionButton.backgroundColor = Colors.reactionButtonBackground
            }
        }
    }
}
