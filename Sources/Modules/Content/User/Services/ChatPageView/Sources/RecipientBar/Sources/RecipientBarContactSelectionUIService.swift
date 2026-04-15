//
//  RecipientBarContactSelectionUIService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

@MainActor
final class RecipientBarContactSelectionUIService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.RecipientBarService.ContactSelectionUI
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.ContactSelectionUI
    private typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.ContactSelectionUI

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI

    // MARK: - Properties

    private(set) var selectedContactPairs = [ContactPair]()

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var contactViews: [UIView] {
        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView else { return [] }
        return recipientBarView.subviews(for: Strings.contactViewSemanticTag)
    }

    private var contactViewSelectionColor: UIColor {
        .init(ThemeService.isDarkModeActive ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)
    }

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Contact Pair Selection

    func deselectContactPair(withViewID contactHash: String) {
        selectedContactPairs.removeAll(where: { $0.contact.encodedHash == contactHash })
        for contactView in contactViews where contactView.identifier == contactHash { contactView.removeFromSuperview() }
        Task.delayed(by: .milliseconds(100)) { @MainActor in
            self.chatPageViewService.inputBar?.configureInputBar()
            guard self.selectedContactPairs.isEmpty else { return }
            self.viewController.messageInputBar.inputTextView.placeholder = nil
        }
    }

    func deselectMockContactPairs() {
        selectedContactPairs.filter(\.isMock).map(\.contact.encodedHash).forEach { deselectContactPair(withViewID: $0) }
        guard let configService = chatPageViewService.recipientBar?.config,
              let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return }

        var view = configService.firstContactView(.onSameLevelAsTextField)
        defer {
            configService.reconfigureTextField(relativeTo: view ?? toLabel)
            configService.reconfigureLastContactView()
        }

        let range = (1 ... Int(Floats.sublevelCount)).reversed()
        guard let sublevel = range.first(where: { configService.firstContactView(.furthestTrailing(onSublevel: $0)) != nil }) else { return }
        view = configService.firstContactView(.furthestTrailing(onSublevel: sublevel))
        configService.reconfigureRecipientBar(forSublevel: sublevel)
        configService.reconfigureCollectionView()
    }

    func selectContactPair(_ contactPair: ContactPair, performInputBarFix: Bool = false) {
        guard !contactPair.containsBlockedUser else {
            Logger.log(
                .init(
                    "Attempted to select contact pair containing blocked user.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ),
                with: .toast(style: nil, isPersistent: false)
            )

            return
        }

        guard !contactPair.containsCurrentUser else {
            Logger.log(
                .init(
                    "Attempted to select contact pair containing current user.",
                    isReportable: false,
                    metadata: .init(sender: self)
                ),
                with: .toast(style: nil, isPersistent: false)
            )

            return
        }

        guard let configService = chatPageViewService.recipientBar?.config,
              let contactView = buildContactView(contactPair.contact.fullName, useRedTextColor: contactPair.isMock),
              let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView,
              selectedContactPairs.count < Int(Floats.selectedContactPairsMaximum) else { return }

        guard !selectedContactPairs.contains(contactPair) else {
            chatPageViewService.recipientBar?.layout.textField?.text = ""
            chatPageViewService.recipientBar?.tableView.setQuery("")
            return
        }

        func addSubview() {
            guard let tableView = chatPageViewService.recipientBar?.layout.tableView,
                  let textField = chatPageViewService.recipientBar?.layout.textField else { return }

            recipientBarView.addSubview(contactView)

            viewController.messagesCollectionView.isHidden = true
            chatPageViewService.recipientBar?.tableView.setQuery("")
            tableView.frame.origin.y = recipientBarView.frame.maxY

            configService.reconfigureTextField(relativeTo: contactView)
            textField.text = nil

            configService.reconfigureCollectionView()
            Task.delayed(by: .milliseconds(100)) { @MainActor in
                self.chatPageViewService.inputBar?.configureInputBar()
            }

            guard !contactPair.isMock else { return }
            viewController.messageInputBar.inputTextView.placeholder = " \(Localized(.newMessage).wrappedValue)"

            guard performInputBarFix else { return }
            chatPageViewService.inputBar?.forceAppearance()
        }

        /// - Returns: A boolean value indicating whether or not the view was configured for the given sublevels.
        func configureContactView(forSublevels sublevels: Int) -> Bool {
            func configureContactView(onSublevel sublevel: Int) -> Bool {
                guard let furthestTrailingView = configService.firstContactView(.furthestTrailing(onSublevel: sublevel)) else { return false }
                guard shouldAddNewSublevel(for: furthestTrailingView) else {
                    contactView.frame.origin.x = furthestTrailingView.frame.maxX + Floats.adjacentViewSpacing
                    contactView.frame.origin.y = furthestTrailingView.frame.origin.y
                    configService.reconfigureRecipientBar(forSublevel: sublevel)
                    return true
                }

                contactView.frame.origin.y = furthestTrailingView.frame.maxY + Floats.adjacentViewSpacing
                configService.reconfigureRecipientBar(forSublevel: sublevel + 1)
                return true
            }

            for sublevel in (1 ... sublevels).reversed() where configureContactView(onSublevel: sublevel) { return true }
            return false
        }

        func shouldAddNewSublevel(for view: UIView) -> Bool {
            (view.frame.maxX + Floats.adjacentViewSpacing) + contactView.frame.width >= recipientBarView.frame.maxX - Floats.recipientBarMaxXDecrement
        }

        contactView.setIdentifier(contactPair.contact.encodedHash)

        if let lastViewID = selectedContactPairs.last?.contact.encodedHash,
           isHighlighted(viewID: lastViewID) {
            deselectContactPair(withViewID: lastViewID)
        }

        deselectMockContactPairs()

        selectedContactPairs.append(contactPair)
        defer { addSubview() }
        guard let furthestTrailingView = configService.firstContactView(.furthestTrailing(onSublevel: nil)) else { return }

        guard shouldAddNewSublevel(for: furthestTrailingView) else {
            guard configureContactView(forSublevels: Int(Floats.sublevelCount)) else {
                contactView.frame.origin.x = furthestTrailingView.frame.maxX + Floats.adjacentViewSpacing
                return
            }

            return
        }

        guard configureContactView(forSublevels: Int(Floats.sublevelCount)) else {
            configService.reconfigureRecipientBar(forSublevel: Int(Floats.recipientBarReconfigurationSublevel))
            contactView.frame.origin.y = furthestTrailingView.frame.maxY + Floats.adjacentViewSpacing
            return
        }
    }

    // MARK: - Label Representation

    func toggleLabelRepresentation(on: Bool) {
        guard let inputBarService = chatPageViewService.inputBar,
              !inputBarService.isForcingAppearance else { return }

        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView else { return }
        UIView.animate(withDuration: Floats.labelRepresentationAnimationDuration) {
            for (index, contactView) in self.contactViews.sorted(by: { $0.frame.maxX < $1.frame.maxX && $0.frame.maxY < $1.frame.maxY }).enumerated() {
                contactView.backgroundColor = on ? UIColor(Colors.labelRepresentationColor) : self.contactViewSelectionColor
                contactView.layer.borderColor = on ? UIColor(Colors.labelRepresentationColor).cgColor : self.contactViewSelectionColor.cgColor

                guard let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel else { continue }
                let redColor = UIColor(Colors.contactViewRedText) // NIT: This should never happen anyway.
                contactLabel.textColor = contactLabel.textColor == redColor || contactView.backgroundColor == redColor ? redColor : UIColor(Colors.accent)
                guard index < self.contactViews.count - 1 else { continue }

                var labelText = (contactLabel.text ?? "")
                while labelText.hasSuffix(",") { labelText = labelText.dropSuffix() }
                contactLabel.text = on ? "\(labelText)," : labelText

                contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
                var width = contactLabel.intrinsicContentSize.width
                while width >= recipientBarView.frame.size.width / Floats.contactViewMaximumWidthDivisor { width -= 1 }
                contactLabel.frame.size.width = width

                guard !on else { continue }

                contactView.frame.size.width = contactLabel.frame.size.width + Floats.contactViewWidthIncrement
                contactLabel.center = .init(x: contactView.bounds.midX, y: contactView.bounds.midY)
            }
        } completion: { _ in
            self.contactViews.forEach { $0.gestureRecognizers?.forEach { $0.isEnabled = !on } }

            guard on else {
                recipientBarView.gestureRecognizers?.removeAll()
                return
            }

            let labelRepresentationTapGesture: UITapGestureRecognizer = .init(target: self, action: #selector(self.labelRepresentationTapGestureRecognized))
            recipientBarView.addGestureRecognizer(labelRepresentationTapGesture)
        }
    }

    // MARK: - View Highlighting

    func isHighlighted(viewID contactHash: String) -> Bool {
        guard let contactView = contactViews.first(where: { $0.identifier == contactHash }),
              let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel,
              contactLabel.textColor == UIColor(Colors.contactViewHighlightedText) else { return false }
        return true
    }

    func toggleIsHighlighted(viewID contactHash: String) {
        guard let contactView = contactViews.first(where: { $0.identifier == contactHash }),
              let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel else { return }

        let redColor = UIColor(Colors.contactViewRedText)

        switch isHighlighted(viewID: contactHash) {
        case true:
            contactLabel.textColor = contactView.backgroundColor == redColor ? redColor : UIColor(Colors.accent)
            contactView.backgroundColor = contactViewSelectionColor
            contactView.layer.borderColor = contactViewSelectionColor.cgColor

        case false:
            contactView.backgroundColor = contactLabel.textColor == redColor ? redColor : UIColor(Colors.accent)
            contactView.layer.borderColor = contactLabel.textColor == redColor ? redColor.cgColor : UIColor(Colors.accent).cgColor
            contactLabel.textColor = UIColor(Colors.contactViewHighlightedText)

            guard let textField = chatPageViewService.recipientBar?.layout.textField,
                  !textField.isFirstResponder else { return }
            textField.becomeFirstResponder()
        }
    }

    func unhighlightAllViews() {
        for contactView in contactViews {
            guard let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel else { continue }
            let redColor = UIColor(Colors.contactViewRedText)
            contactLabel.textColor = contactLabel.textColor == redColor || contactView.backgroundColor == redColor ? redColor : UIColor(Colors.accent)

            contactView.backgroundColor = contactViewSelectionColor
            contactView.layer.borderColor = contactViewSelectionColor.cgColor
        }
    }

    // MARK: - Auxiliary

    @objc
    private func contactViewTapGestureRecognized(recognizer: UITapGestureRecognizer) {
        guard let contactView = recognizer.view,
              contactView.identifier == chatPageViewService.recipientBar?.config.firstContactView(.onSameLevelAsTextField)?.identifier else { return }
        toggleIsHighlighted(viewID: contactView.identifier)
    }

    @objc
    private func labelRepresentationTapGestureRecognized() {
        chatPageViewService.recipientBar?.layout.textField?.becomeFirstResponder()
    }

    // MARK: - View Builders

    private func buildContactView(_ text: String, useRedTextColor: Bool) -> UIView? {
        guard let recipientBarView = chatPageViewService.recipientBar?.layout.recipientBarView,
              let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return nil }

        // Create contact view

        let contactView: UIView = .init(frame: .init(
            origin: .init(x: Floats.contactViewFrameXOrigin, y: 0),
            size: .init(width: 0, height: Floats.contactViewFrameHeight)
        ))

        contactView.alpha = UIApplication.isFullyV26Compatible ? Floats.v26ContactViewAlpha : 1
        contactView.backgroundColor = contactViewSelectionColor
        contactView.center.y = toLabel.center.y
        contactView.isUserInteractionEnabled = true

        contactView.layer.borderColor = contactViewSelectionColor.cgColor
        contactView.layer.borderWidth = 1
        contactView.layer.cornerRadius = Floats.contactViewCornerRadius

        contactView.frame.origin.x = toLabel.frame.maxX + Floats.contactViewXOriginIncrement

        let contactViewTapGesture: UITapGestureRecognizer = .init(target: self, action: #selector(contactViewTapGestureRecognized))
        contactView.addGestureRecognizer(contactViewTapGesture)

        // Create contact label

        let contactLabel: UILabel = .init()
        contactLabel.font = .systemFont(ofSize: Floats.contactLabelSystemFontSize)

        contactLabel.text = text
        contactLabel.textAlignment = .center
        contactLabel.textColor = useRedTextColor ? UIColor(Colors.contactViewRedText) : UIColor(Colors.accent)

        contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
        contactLabel.frame.size.width = contactLabel.intrinsicContentSize.width

        while contactLabel.frame.size.width >= recipientBarView.frame.size.width / Floats.contactViewMaximumWidthDivisor { contactLabel.frame.size.width -= 1 }

        // Add label to enclosing view

        contactView.addSubview(contactLabel)
        contactView.frame.size.width = contactLabel.frame.size.width + Floats.contactViewWidthIncrement
        contactLabel.center = .init(x: contactView.bounds.midX, y: contactView.bounds.midY)

        contactView.tag = coreUI.semTag(for: Strings.contactViewSemanticTag)
        contactLabel.tag = coreUI.semTag(for: Strings.contactLabelSemanticTag)

        return contactView
    }
}
