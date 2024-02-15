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

// swiftlint:disable:next type_body_length
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

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.commonServices.contact.contactPairArchive) private var contactPairArchive: ContactPairArchiveService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking.services.user) private var userService: UserService

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

    public func deselectMockContactPairs() {
        selectedContactPairs.filter { $0.isMock }.map(\.contact.encodedHash).forEach { deselectContactPair(withViewID: $0) }
        guard let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return }
        var view = firstContactView(.onSameLevelAsTextField)
        defer { reconfigureTextField(relativeTo: view ?? toLabel) }
        let range = (1 ... Int(Floats.sublevelCount)).reversed()
        guard let sublevel = range.first(where: { firstContactView(.furthestTrailing(onSublevel: $0)) != nil }) else { return }
        view = firstContactView(.furthestTrailing(onSublevel: sublevel))
        reconfigureRecipientBar(forSublevel: sublevel)
    }

    public func selectContactPair(_ contactPair: ContactPair) {
        guard let contactView = buildContactView(contactPair.contact.fullName, useRedTextColor: contactPair.isMock),
              let recipientBar,
              selectedContactPairs.count < Int(Floats.selectedContactPairsMaximum) else { return }

        func addSubview() {
            guard let tableView = chatPageViewService.recipientBar?.layout.tableView,
                  let textField = chatPageViewService.recipientBar?.layout.textField else { return }

            recipientBar.addSubview(contactView)

            chatPageViewService.recipientBar?.tableView.setQuery("")
            tableView.frame.origin.y = recipientBar.frame.maxY

            reconfigureTextField(relativeTo: contactView)
            textField.text = nil
        }

        /// - Returns: A boolean value indicating whether or not the view was configured for the given sublevels.
        func configureContactView(forSublevels sublevels: Int) -> Bool {
            func configureContactView(onSublevel sublevel: Int) -> Bool {
                guard let furthestTrailingView = firstContactView(.furthestTrailing(onSublevel: sublevel)) else { return false }
                guard shouldAddNewSublevel(for: furthestTrailingView) else {
                    contactView.frame.origin.x = furthestTrailingView.frame.maxX + Floats.adjacentViewSpacing
                    contactView.frame.origin.y = furthestTrailingView.frame.origin.y
                    reconfigureRecipientBar(forSublevel: sublevel)
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

        deselectMockContactPairs()

        selectedContactPairs.append(contactPair)
        defer { addSubview() }
        guard let furthestTrailingView = firstContactView(.furthestTrailing(onSublevel: nil)) else { return }

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

    public func unhighlightAllViews() {
        for contactView in contactViews {
            guard let contactLabel = contactView.firstSubview(for: Strings.contactLabelSemanticTag) as? UILabel else { continue }
            contactLabel.textColor = contactLabel.textColor == UIColor(Colors.contactViewRedText) ? UIColor(Colors.contactViewRedText) : .accent

            let selectionColor = UIColor(ThemeService.isDarkModeActive ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)
            contactView.backgroundColor = selectionColor
            contactView.layer.borderColor = selectionColor.cgColor
        }
    }

    // MARK: - On Superfluous Backspace

    public func onSuperflousBackspace() {
        /// - Returns: A boolean value indicating whether or not the view was configured for the given sublevels.
        func configureTextField(forSublevels sublevels: Int) -> Bool {
            func configureTextField(onSublevel sublevel: Int) -> Bool {
                guard let furthestTrailingView = firstContactView(.furthestTrailing(onSublevel: sublevel)) else { return false }
                reconfigureRecipientBar(forSublevel: sublevel)
                reconfigureTextField(relativeTo: furthestTrailingView)
                return true
            }

            for sublevel in (1 ... sublevels).reversed() where configureTextField(onSublevel: sublevel) { return true }
            return false
        }

        guard let firstContactView = firstContactView(.onSameLevelAsTextField) else { return }
        guard isHighlighted(viewID: firstContactView.identifier) else {
            toggleIsHighlighted(viewID: firstContactView.identifier)
            return
        }

        deselectContactPair(withViewID: firstContactView.identifier)

        guard !configureTextField(forSublevels: Int(Floats.sublevelCount)),
              let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return }
        reconfigureTextField(relativeTo: toLabel)
    }

    // MARK: - Text Field Should Return

    public func textFieldShouldReturn(_ text: String) {
        Task { @MainActor in
            guard !text.isBlank else {
                guard !selectedContactPairs.filter({ $0.isMock }).isEmpty else {
                    unhighlightAllViews()
                    chatPageViewService.inputBar?.becomeFirstResponder()
                    return
                }

                unhighlightAllViews()
                deselectMockContactPairs()
                core.gcd.after(.milliseconds(Floats.becomeFirstResponderDelayMilliseconds)) { self.chatPageViewService.inputBar?.becomeFirstResponder() }
                return
            }

            let phoneNumber = PhoneNumber(text)
            guard !phoneNumber.compiledNumberString.isBlank,
                  text.digits.count == text.count else {
                selectContactPair(.mock(withName: text))
                return
            }

            let getUsersResult = await userService.getUsers(phoneNumber: phoneNumber)

            switch getUsersResult {
            case let .success(users):
                guard let firstUser = users.first else { return } // TODO: Need action for multiple users.
                guard let contactPair = contactPairArchive.getValue(userNumberHash: firstUser.phoneNumber.nationalNumberString.digits.encodedHash) else {
                    selectContactPair(.withUser(firstUser))
                    return
                }

                selectContactPair(contactPair)

            case .failure:
                selectContactPair(.mock(withName: text))
            }
        }
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

        let redColor = UIColor(Colors.contactViewRedText)

        switch isHighlighted(viewID: contactHash) {
        case true:
            let selectionColor = UIColor(ThemeService.isDarkModeActive ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)
            contactLabel.textColor = contactView.backgroundColor == redColor ? redColor : .accent
            contactView.backgroundColor = selectionColor
            contactView.layer.borderColor = selectionColor.cgColor

        case false:
            contactView.backgroundColor = contactLabel.textColor == redColor ? redColor : .accent
            contactView.layer.borderColor = contactLabel.textColor == redColor ? redColor.cgColor : UIColor.accent.cgColor
            contactLabel.textColor = UIColor(Colors.contactViewHighlightedText)
        }
    }

    // MARK: - Auxiliary

    private func deselectContactPair(withViewID contactHash: String) {
        selectedContactPairs.removeAll(where: { $0.contact.encodedHash == contactHash })
        for contactView in contactViews where contactView.identifier == contactHash { contactView.removeFromSuperview() }
    }

    private func firstContactView(_ configuration: ContactViewSpacialConfiguration) -> UIView? {
        var subviews = contactViews

        switch configuration {
        case let .furthestTrailing(onSublevel: sublevel):
            if let sublevel { subviews = subviews.filter { $0.frame.maxY == (Floats.initialLevelMaxY + value(for: sublevel)) } }
            return subviews.sorted(by: { $0.frame.maxX > $1.frame.maxX }).first

        case .onSameLevelAsTextField:
            guard let textField = chatPageViewService.recipientBar?.layout.textField else { return nil }
            return subviews
                .filter { $0.center.y == textField.center.y }
                .sorted(by: { $0.frame.maxX > $1.frame.maxX })
                .first
        }
    }

    private func reconfigureRecipientBar(forSublevel sublevel: Int) {
        guard let recipientBar,
              let tableView = chatPageViewService.recipientBar?.layout.tableView else { return }
        typealias Floats = AppConstants.CGFloats.RecipientBarLayoutService
        let recipientBarFrameHeight = Floats.frameHeight + value(for: sublevel)
        recipientBar.frame.size.height = recipientBarFrameHeight
        chatPageViewService.recipientBar?.layout.configureBorders()
        tableView.contentInset.bottom = recipientBarFrameHeight
    }

    private func reconfigureTextField(relativeTo view: UIView) {
        guard let recipientBar,
              let textField = chatPageViewService.recipientBar?.layout.textField,
              let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return }

        let isOnInitialLevel = (textField.center.y == toLabel.center.y || view.frame.maxY == Floats.initialLevelMaxY) // swiftlint:disable:next line_length
        let widthDecrement = isOnInitialLevel ? Floats.textFieldReconfigurationInitialLevelWidthDecrement : Floats.textFieldReconfigurationNotInitialLevelWidthDecrement

        textField.frame.origin.x = view.frame.maxX + Floats.textFieldReconfigurationXOriginIncrement
        textField.frame.size.width = (recipientBar.frame.maxX - textField.frame.origin.x) - widthDecrement
        textField.center.y = view.center.y
    }

    @objc
    private func tapGestureRecognized(recognizer: UITapGestureRecognizer) {
        guard let contactView = recognizer.view,
              contactView.identifier == firstContactView(.onSameLevelAsTextField)?.identifier else { return }
        toggleIsHighlighted(viewID: contactView.identifier)
    }

    private func value(for sublevel: Int) -> CGFloat { Floats.sublevelMultiplier * (sublevel - 1 < 0 ? 1 : .init(sublevel) - 1) }

    // MARK: - View Builders

    private func buildContactView(_ text: String, useRedTextColor: Bool) -> UIView? {
        guard let recipientBar,
              let toLabel = chatPageViewService.recipientBar?.layout.toLabel else { return nil }

        // Create contact view

        let contactView: UIView = .init(frame: .init(
            origin: .init(x: Floats.contactViewFrameXOrigin, y: 0),
            size: .init(width: 0, height: Floats.contactViewFrameHeight)
        ))

        let selectionColor = UIColor(ThemeService.isDarkModeActive ? Colors.contactViewDarkSelection : Colors.contactViewLightSelection)

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
        contactLabel.font = .systemFont(ofSize: Floats.contactLabelSystemFontSize)

        contactLabel.text = text
        contactLabel.textAlignment = .center
        contactLabel.textColor = useRedTextColor ? UIColor(Colors.contactViewRedText) : .accent

        contactLabel.frame.size.height = contactLabel.intrinsicContentSize.height
        contactLabel.frame.size.width = contactLabel.intrinsicContentSize.width

        if let maximumWidth = chatPageViewService.recipientBar?.layout.screenWidth {
            while contactLabel.frame.size.width >= maximumWidth / Floats.contactViewMaximumWidthDivisor { contactLabel.frame.size.width -= 1 }
        }

        // Add label to enclosing view

        contactView.addSubview(contactLabel)
        contactView.frame.size.width = contactLabel.frame.size.width + Floats.contactViewWidthIncrement
        contactLabel.center = .init(x: contactView.bounds.midX, y: contactView.bounds.midY)

        contactView.tag = core.ui.semTag(for: Strings.contactViewSemanticTag)
        contactLabel.tag = core.ui.semTag(for: Strings.contactLabelSemanticTag)

        return contactView
    }
}
