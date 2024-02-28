//
//  RecipientBarLayoutService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import Redux

public final class RecipientBarLayoutService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.RecipientBarService.Layout
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.Layout
    private typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.Layout

    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var wasTextFieldFirstResponder = false

    // MARK: - Computed Properties

    public var recipientBarView: RecipientBar? { viewController.view.firstSubview(for: Strings.recipientBarSemanticTag) as? RecipientBar }
    public var selectContactButton: UIButton? { recipientBarView?.firstSubview(for: Strings.selectContactButtonSemanticTag) as? UIButton }
    public var tableView: UITableView? { viewController.view.firstSubview(for: Strings.tableViewSemanticTag) as? UITableView }
    public var textField: UITextField? { recipientBarView?.firstSubview(for: Strings.textFieldSemanticTag) as? UITextField }
    public var toLabel: UILabel? { recipientBarView?.firstSubview(for: Strings.toLabelSemanticTag) as? UILabel }
    public var viewFrame: CGRect { .init(origin: .zero, size: .init(width: screenWidth, height: Floats.frameHeight)) }

    private var screenWidth: CGFloat { getScreenWidth() }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Layout Subviews

    public func layoutSubviews() {
        configureBackgroundColor()
        configureBorders()

        configureSelectContactButton()
        configureTableView()
        configureToLabel()
        configureTextField()
    }

    // MARK: - Remove from Superview

    public func removeFromSuperview() {
        Task { @MainActor in
            recipientBarView?.removeFromSuperview()
            viewController.messagesCollectionView.contentInset.top = 0
            viewController.messagesCollectionView.verticalScrollIndicatorInsets.top = 0

            guard let actionHandlerService = service?.actionHandler,
                  let parent = viewController.parent else { return }

            let doneButton = UIBarButtonItem(
                title: Localized(.done).wrappedValue,
                style: .done,
                target: actionHandlerService,
                action: #selector(actionHandlerService.doneButtonTapped)
            )

            doneButton.tintColor = .accent
            parent.navigationItem.rightBarButtonItem = doneButton

            guard let conversation = viewController.currentConversation,
                  let cellViewData = ConversationCellViewData(conversation) else { return }

            parent.navigationItem.title = cellViewData.titleLabelText
        }
    }

    // MARK: - Set Is User Interaction Enabled

    public func setIsUserInteractionEnabled(_ isUserInteractionEnabled: Bool) {
        Task { @MainActor in
            guard let recipientBarView,
                  let textField else { return }

            switch isUserInteractionEnabled {
            case true:
                recipientBarView.isUserInteractionEnabled = true
                guard wasTextFieldFirstResponder else { return }
                textField.becomeFirstResponder()

            case false:
                wasTextFieldFirstResponder = textField.isFirstResponder
                recipientBarView.isUserInteractionEnabled = false
            }
        }
    }

    // MARK: - UI Configuration

    public func configureBorders() {
        func satisfiesConstraints(_ layer: CALayer) -> Bool {
            guard layer.backgroundColor == UIColor(Colors.darkBorder).cgColor || layer.backgroundColor == UIColor(Colors.lightBorder).cgColor,
                  layer.frame.height == Floats.borderHeight else { return false }
            return true
        }

        guard let recipientBarView else { return }

        var borderColor = UIColor(ThemeService.isDarkModeActive ? Colors.darkBorder : Colors.lightBorder).cgColor
        if ThemeService.currentTheme != AppTheme.default.theme {
            borderColor = UIColor(Colors.darkBorder).cgColor
        }

        recipientBarView.layer.sublayers?.removeAll(where: { satisfiesConstraints($0) })

        let bottomBorder = CALayer()
        let topBorder = CALayer()

        bottomBorder.frame = .init(
            origin: .init(x: 0, y: recipientBarView.frame.size.height - Floats.borderHeight),
            size: .init(width: recipientBarView.frame.size.width, height: Floats.borderHeight)
        )
        bottomBorder.backgroundColor = borderColor

        topBorder.frame = .init(
            origin: .zero,
            size: .init(width: recipientBarView.frame.size.width, height: Floats.borderHeight)
        )
        topBorder.backgroundColor = borderColor

        recipientBarView.layer.addSublayer(bottomBorder)
        recipientBarView.layer.addSublayer(topBorder)
    }

    private func configureBackgroundColor() {
        let darkBackground: UIColor = ThemeService.currentTheme == AppTheme.default.theme ? .listViewBackground : .background
        let lightBackground = UIColor(Colors.lightBackground).withAlphaComponent(Floats.lightBackgroundColorAlphaComponent)
        recipientBarView?.backgroundColor = ThemeService.isDarkModeActive ? darkBackground : lightBackground
    }

    private func configureSelectContactButton() {
        guard let recipientBarView,
              recipientBarView.subviews(for: Strings.selectContactButtonSemanticTag).isEmpty,
              let selectContactButton = buildSelectContactButton() else { return }
        selectContactButton.tag = core.ui.semTag(for: Strings.selectContactButtonSemanticTag)
        recipientBarView.addSubview(selectContactButton)
    }

    private func configureTableView() {
        guard viewController.view.subviews.filter({ $0 is UITableView }).isEmpty, // TODO: Audit this.
              let tableView = buildTableView() else { return }
        tableView.tag = core.ui.semTag(for: Strings.tableViewSemanticTag)
        viewController.view.addSubview(tableView) // TODO: Needs additional configuration.
    }

    private func configureTextField() {
        guard let recipientBarView,
              recipientBarView.subviews(for: Strings.textFieldSemanticTag).isEmpty,
              let textField = buildTextField() else { return }
        textField.tag = core.ui.semTag(for: Strings.textFieldSemanticTag)
        recipientBarView.addSubview(textField)
    }

    private func configureToLabel() {
        guard let recipientBarView,
              recipientBarView.subviews(for: Strings.toLabelSemanticTag).isEmpty,
              let toLabel = buildToLabel() else { return }
        toLabel.tag = core.ui.semTag(for: Strings.toLabelSemanticTag)
        recipientBarView.addSubview(toLabel)
    }

    // MARK: - Auxiliary

    private func getScreenWidth() -> CGFloat {
        @Dependency(\.uiApplication.mainScreen?.bounds.width) var mainScreenWidth: CGFloat?
        return mainScreenWidth ?? UIScreen.main.bounds.width
    }

    // MARK: - View Builders

    private func buildSelectContactButton() -> UIButton? {
        guard let actionHandlerService = service?.actionHandler,
              let recipientBarView else { return nil }

        let selectContactButton: UIButton = .init(type: .contactAdd)
        selectContactButton.tintColor = .accent

        selectContactButton.addTarget(
            actionHandlerService,
            action: #selector(actionHandlerService.selectContactButtonTapped),
            for: .touchUpInside
        )

        selectContactButton.frame.size.height = selectContactButton.intrinsicContentSize.height
        selectContactButton.frame.size.width = selectContactButton.intrinsicContentSize.width

        let xOriginOffset = recipientBarView.frame.maxX - selectContactButton.intrinsicContentSize.width
        selectContactButton.frame.origin.x = xOriginOffset - Floats.selectContactButtonXOriginDecrement
        selectContactButton.center.y = recipientBarView.center.y

        return selectContactButton
    }

    private func buildTableView() -> UITableView? {
        let tableView: UITableView = .init(frame: viewController.view.frame)

        tableView.alpha = 0
        tableView.contentInset.bottom = Floats.frameHeight
        tableView.frame.origin.y += Floats.frameHeight
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Strings.tableViewCellReuseIdentifier)

        return tableView
    }

    private func buildTextField() -> UITextField? {
        guard let recipientBarView,
              let service,
              let toLabel else { return nil }

        let textField: RecipientBarTextField = .init(frame: .init(
            origin: .zero,
            size: .init(width: screenWidth - Floats.textFieldWidthDecrement, height: Floats.frameHeight)
        ))
        textField.onSuperfluousBackspace { service.actionHandler.onSuperflousBackspace() }

        textField.addTarget(
            service.actionHandler,
            action: #selector(service.actionHandler.textFieldChanged(_:)),
            for: .editingChanged
        )
        textField.delegate = recipientBarView

        textField.frame.origin.x = toLabel.frame.maxX + Floats.textFieldXOriginIncrement

        textField.autocorrectionType = .no
        textField.keyboardType = .namePhonePad
        textField.spellCheckingType = .no

        return textField
    }

    private func buildToLabel() -> UILabel? {
        guard let recipientBarView else { return nil }

        let toLabel: UILabel = .init(frame: .init(
            origin: .init(x: Floats.toLabelXOrigin, y: 0),
            size: .init(width: 0, height: Floats.frameHeight)
        ))

        toLabel.font = UIFont(name: Strings.toLabelFontName, size: Floats.toLabelFontSize)
        toLabel.text = Localized(.to).wrappedValue
        toLabel.textColor = .init(Colors.toLabelText)

        toLabel.frame.size.width = toLabel.intrinsicContentSize.width
        toLabel.center.y = recipientBarView.center.y

        return toLabel
    }
}
