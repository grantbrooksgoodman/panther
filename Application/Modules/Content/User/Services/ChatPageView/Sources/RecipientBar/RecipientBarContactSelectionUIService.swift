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

/* 3rd-party */
import Redux

public final class RecipientBarContactSelectionUIService {
    // MARK: - Types

    private enum ContactViewSpacialConfiguration {
        case furthestTrailing(onSublevel: Int? = nil)
        case onSameLevelAsTextField
    }

    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.RecipientBarContactSelectionUIService
    private typealias Floats = AppConstants.CGFloats.RecipientBarContactSelectionUIService
    private typealias Strings = AppConstants.Strings.RecipientBarContactSelectionUIService

    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    public private(set) var selectedContactPairs = [ContactPair]()

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    private var contactViews: [UIView] {
        guard let recipientBar else { return [] }
        return recipientBar.subviews(for: Strings.contactViewSemanticTag)
    }

    private var recipientBar: RecipientBar? {
        typealias Strings = AppConstants.Strings.RecipientBarLayoutService
        return viewController.view.firstSubview(for: Strings.recipientBarSemanticTag) as? RecipientBar
    }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Contact Pair Selection

    public func deselectContactPair(withViewID contactHash: String) {
        selectedContactPairs.removeAll(where: { $0.contact.encodedHash == contactHash })
        for contactView in contactViews where contactView.identifier == contactHash { contactView.removeFromSuperview() }
    }

    public func selectContactPair(_ contactPair: ContactPair) {
        guard let contactView = buildContactView(contactPair.contact.fullName),
              let recipientBar,
              selectedContactPairs.count < Int(Floats.selectedContactPairsMaximum) else { return }

        func addSubview() {
            guard let tableView = service?.layout.tableView,
                  let textField = service?.layout.textField else { return }

            recipientBar.addSubview(contactView)
            unhighlightAllCells()

            service?.tableView.setQuery("")
            tableView.frame.origin.y = recipientBar.frame.maxY

            reconfigureTextField(relativeTo: contactView)
            textField.text = nil
        }

        /// - Returns: A boolean value indicating whether or not the view was configured for the given sublevels.
        func configureContactView(forSublevels sublevels: Int) -> Bool {
            func configureContactView(onSublevel sublevel: Int) -> Bool {
                guard let furthestTrailingView = findContactView(.furthestTrailing(onSublevel: sublevel)) else { return false }
                guard shouldAddNewSublevel(for: furthestTrailingView) else {
                    contactView.frame.origin.x = furthestTrailingView.frame.maxX + Floats.adjacentViewSpacing
                    contactView.frame.origin.y = furthestTrailingView.frame.origin.y
                    return true
                }

                contactView.frame.origin.y = furthestTrailingView.frame.maxY + Floats.adjacentViewSpacing
                reconfigureRecipientBar(forSublevel: sublevel + 1)
                return true
            }

            for sublevel in (1 ... sublevels).reversed() where configureContactView(onSublevel: sublevel) { return true }
            return false
        }

        func shouldAddNewSublevel(for view: UIView) -> Bool {
            (view.frame.maxX + Floats.adjacentViewSpacing) + contactView.frame.width >= recipientBar.frame.maxX - Floats.recipientBarMaxXDecrement
        }

        contactView.setIdentifier(contactPair.contact.encodedHash)

        if let lastViewID = selectedContactPairs.last?.contact.encodedHash,
           isHighlighted(viewID: lastViewID) {
            deselectContactPair(withViewID: lastViewID)
        }

        selectedContactPairs.append(contactPair)
        defer { addSubview() }
        guard let furthestTrailingView = findContactView(.furthestTrailing(onSublevel: nil)) else { return }

        guard shouldAddNewSublevel(for: furthestTrailingView) else {
            guard configureContactView(forSublevels: Int(Floats.sublevelCount)) else {
                contactView.frame.origin.x = furthestTrailingView.frame.maxX + Floats.adjacentViewSpacing
                return
            }

            return
        }

        guard configureContactView(forSublevels: Int(Floats.sublevelCount)) else {
            reconfigureRecipientBar(forSublevel: Int(Floats.recipientBarReconfigurationSublevel)) // TODO: Audit this.
            contactView.frame.origin.y = furthestTrailingView.frame.maxY + Floats.adjacentViewSpacing
            return
        }

        addSubview()
    }

    // MARK: - On Superfluous Backspace

    public func onSuperflousBackspace() {
        guard let recipientBar else { return }

        /// - Returns: A boolean value indicating whether or not the view was configured for the given sublevels.
        func configureTextField(forSublevels sublevels: Int) -> Bool {
            func configureTextField(onSublevel sublevel: Int) -> Bool {
                guard let furthestTrailingView = findContactView(.furthestTrailing(onSublevel: sublevel)) else { return false }
                reconfigureRecipientBar(forSublevel: sublevel)
                reconfigureTextField(relativeTo: furthestTrailingView)
                return true
            }

            for sublevel in (1 ... sublevels).reversed() where configureTextField(onSublevel: sublevel) { return true }
            return false
        }

        guard let firstView = findContactView(.onSameLevelAsTextField) else { return }
        guard isHighlighted(viewID: firstView.identifier) else {
            toggleIsHighlighted(viewID: firstView.identifier)
            return
        }

        deselectContactPair(withViewID: firstView.identifier)

        guard !configureTextField(forSublevels: Int(Floats.sublevelCount)) else { return }
        reconfigureTextField(relativeTo: recipientBar)
    }

    // MARK: - View Highlighting

    private func isHighlighted(viewID contactHash: String) -> Bool {
        guard let contactView = contactViews.first(where: { $0.identifier == contactHash }),
              let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel,
              contactLabel.textColor == UIColor(Colors.contactViewHighlightedText) else { return false }
        return true
    }

    private func toggleIsHighlighted(viewID contactHash: String) {
        guard let contactView = contactViews.first(where: { $0.identifier == contactHash }),
              let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel else { return }

        switch isHighlighted(viewID: contactHash) {
        case true:
            contactLabel.textColor = .accent
            let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            let selectionColor = UIColor(isDarkMode ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)
            contactView.backgroundColor = selectionColor
            contactView.layer.borderColor = selectionColor.cgColor

        case false:
            contactLabel.textColor = UIColor(Colors.contactViewHighlightedText)
            contactView.backgroundColor = .accent
            contactView.layer.borderColor = UIColor.accent.cgColor
        }
    }

    private func unhighlightAllCells() {
        for contactView in contactViews {
            guard let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel else { continue }
            contactLabel.textColor = .accent

            let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            let selectionColor = UIColor(isDarkMode ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)
            contactView.backgroundColor = selectionColor
            contactView.layer.borderColor = selectionColor.cgColor
        }
    }

    // MARK: - Auxiliary

    private func findContactView(_ configuration: ContactViewSpacialConfiguration) -> UIView? {
        var subviews = contactViews

        switch configuration {
        case let .furthestTrailing(onSublevel: sublevel):
            if let sublevel { subviews = subviews.filter { $0.frame.maxY == (Floats.initialLevelMaxY + value(for: sublevel)) } }
            return subviews.sorted(by: { $0.frame.maxX > $1.frame.maxX }).first

        case .onSameLevelAsTextField:
            guard let textField = service?.layout.textField else { return nil }
            return subviews
                .filter { $0.center.y == textField.center.y }
                .sorted(by: { $0.frame.maxX > $1.frame.maxX })
                .first
        }
    }

    private func reconfigureRecipientBar(forSublevel sublevel: Int) {
        guard let recipientBar else { return }
        typealias Floats = AppConstants.CGFloats.RecipientBarLayoutService
        recipientBar.frame.size.height = Floats.frameHeight + value(for: sublevel)
        service?.layout.configureBorders()
    }

    private func reconfigureTextField(relativeTo view: UIView) {
        guard let recipientBar,
              let textField = service?.layout.textField,
              let toLabel = service?.layout.toLabel else { return }

        typealias Strings = AppConstants.Strings.RecipientBarLayoutService

        let isOnInitialLevel = (textField.center.y == toLabel.center.y || view.frame.maxY == Floats.initialLevelMaxY)
        let relatedViewIsRecipientBar = view.tag == coreUI.semTag(for: Strings.recipientBarSemanticTag)

        // swiftlint:disable line_length
        let widthDecrement = isOnInitialLevel ? Floats.textFieldReconfigurationInitialLevelWidthDecrement : Floats.textFieldReconfigurationNotInitialLevelWidthDecrement
        let xOriginIncrement = relatedViewIsRecipientBar ? Floats.textFieldReconfigurationRecipientBarXOriginIncrement : Floats.textFieldReconfigurationNotRecipientBarXOriginIncrement
        // swiftlint:enable line_length

        textField.frame.origin.x = (relatedViewIsRecipientBar ? toLabel : view).frame.maxX + xOriginIncrement
        textField.frame.size.width = (recipientBar.frame.maxX - textField.frame.origin.x) - widthDecrement
        textField.center.y = view.center.y
    }

    @objc
    private func tapGestureRecognized(recognizer: UITapGestureRecognizer) {
        guard let contactView = recognizer.view else { return }
        toggleIsHighlighted(viewID: contactView.identifier)
    }

    private func value(for sublevel: Int) -> CGFloat { Floats.sublevelMultiplier * (sublevel - 1 < 0 ? 1 : .init(sublevel) - 1) }

    // MARK: - View Builders

    private func buildContactView(_ text: String, useRedTextColor: Bool = false) -> UIView? {
        guard let recipientBar,
              let toLabel = service?.layout.toLabel else { return nil }

        // Create contact view

        let contactView: UIView = .init(frame: .init(
            origin: .init(x: Floats.contactViewFrameXOrigin, y: 0),
            size: .init(width: 0, height: Floats.contactViewFrameHeight)
        ))

        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        let selectionColor = UIColor(isDarkMode ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)

        contactView.backgroundColor = selectionColor
        contactView.center.y = recipientBar.center.y
        contactView.isUserInteractionEnabled = true

        contactView.layer.borderColor = selectionColor.cgColor
        contactView.layer.borderWidth = 1
        contactView.layer.cornerRadius = Floats.contactViewCornerRadius

        contactView.frame.origin.x = toLabel.frame.maxX + Floats.contactViewXOriginIncrement

        let tapGesture: UITapGestureRecognizer = .init(target: self, action: #selector(tapGestureRecognized))
        contactView.addGestureRecognizer(tapGesture)

        // Create contact label

        let contactLabel: UILabel = .init()
        contactLabel.text = text
        contactLabel.textAlignment = .center
        contactLabel.textColor = useRedTextColor ? UIColor(Colors.contactViewRedText) : .accent

        contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
        contactLabel.frame.size.width = contactLabel.intrinsicContentSize.width

        if let maximumWidth = service?.layout.screenWidth {
            while contactLabel.frame.size.width >= maximumWidth / Floats.contactViewMaximumWidthDivisor { contactLabel.frame.size.width -= 1 }
        }

        // Add label to enclosing view

        contactView.addSubview(contactLabel)
        contactView.frame.size.width = contactLabel.frame.size.width + Floats.contactViewWidthIncrement
        contactLabel.center = .init(x: contactView.bounds.midX, y: contactView.bounds.midY)

        contactView.tag = coreUI.semTag(for: Strings.contactViewSemanticTag)
        contactLabel.tag = coreUI.semTag(for: Strings.contactLabelSemanticTag)

        return contactView
    }
}
