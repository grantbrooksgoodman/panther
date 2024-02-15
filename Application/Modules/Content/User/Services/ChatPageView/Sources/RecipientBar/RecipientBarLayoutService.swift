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

    private typealias Colors = AppConstants.Colors.RecipientBarLayoutService
    private typealias Floats = AppConstants.CGFloats.RecipientBarLayoutService
    private typealias Strings = AppConstants.Strings.RecipientBarLayoutService

    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.chatPageViewService.recipientBar) private var service: RecipientBarService?

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Computed Properties

    public var screenWidth: CGFloat { getScreenWidth() }
    public var tableView: UITableView? { viewController.messagesCollectionView.superview?.firstSubview(for: Strings.tableViewSemanticTag) as? UITableView }
    public var textField: UITextField? { recipientBar?.firstSubview(for: Strings.textFieldSemanticTag) as? UITextField }
    public var toLabel: UILabel? { recipientBar?.firstSubview(for: Strings.toLabelSemanticTag) as? UILabel }
    public var viewFrame: CGRect { .init(origin: .zero, size: .init(width: screenWidth, height: Floats.frameHeight)) }

    private var recipientBar: RecipientBar? { viewController.view.firstSubview(for: Strings.recipientBarSemanticTag) as? RecipientBar }
    private var selectContactButton: UIButton? { recipientBar?.firstSubview(for: Strings.selectContactButtonSemanticTag) as? UIButton }

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

    // MARK: - UI Configuration

    public func configureBorders() {
        guard let recipientBar else { return }

        var borderColor = UIColor(UITraitCollection.current.userInterfaceStyle == .dark ? Colors.darkBorder : Colors.lightBorder).cgColor
        if ThemeService.currentTheme != AppTheme.default.theme {
            borderColor = UIColor(Colors.darkBorder).cgColor
        }

        recipientBar.layer.sublayers?.removeAll(where: { $0.backgroundColor == borderColor && $0.frame.height == Floats.borderHeight })

        let bottomBorder = CALayer()
        let topBorder = CALayer()

        bottomBorder.frame = .init(
            origin: .init(x: 0, y: recipientBar.frame.size.height - Floats.borderHeight),
            size: .init(width: recipientBar.frame.size.width, height: Floats.borderHeight)
        )
        bottomBorder.backgroundColor = borderColor

        topBorder.frame = .init(
            origin: .zero,
            size: .init(width: recipientBar.frame.size.width, height: Floats.borderHeight)
        )
        topBorder.backgroundColor = borderColor

        recipientBar.layer.addSublayer(bottomBorder)
        recipientBar.layer.addSublayer(topBorder)
    }

    private func configureBackgroundColor() {
        let darkBackground: UIColor = ThemeService.currentTheme == AppTheme.default.theme ? .listViewBackground : .background
        let lightBackground = UIColor(Colors.lightBackground).withAlphaComponent(Floats.lightBackgroundColorAlphaComponent)
        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        recipientBar?.backgroundColor = isDarkMode ? darkBackground : lightBackground
    }

    private func configureSelectContactButton() {
        guard let recipientBar,
              recipientBar.subviews(for: Strings.selectContactButtonSemanticTag).isEmpty,
              let selectContactButton = buildSelectContactButton() else { return }
        selectContactButton.tag = coreUI.semTag(for: Strings.selectContactButtonSemanticTag)
        recipientBar.addSubview(selectContactButton)
    }

    private func configureTableView() {
        guard let superview = viewController.messagesCollectionView.superview,
              superview.subviews.filter({ $0 is UITableView }).isEmpty, // TODO: Audit this.
              let tableView = buildTableView() else { return }
        tableView.tag = coreUI.semTag(for: Strings.tableViewSemanticTag)
        superview.addSubview(tableView) // TODO: Needs additional configuration.
    }

    private func configureTextField() {
        guard let recipientBar,
              recipientBar.subviews(for: Strings.textFieldSemanticTag).isEmpty,
              let textField = buildTextField() else { return }
        textField.tag = coreUI.semTag(for: Strings.textFieldSemanticTag)
        recipientBar.addSubview(textField)
    }

    private func configureToLabel() {
        guard let recipientBar,
              recipientBar.subviews(for: Strings.toLabelSemanticTag).isEmpty,
              let toLabel = buildToLabel() else { return }
        toLabel.tag = coreUI.semTag(for: Strings.toLabelSemanticTag)
        recipientBar.addSubview(toLabel)
    }

    // MARK: - Auxiliary

    private func getScreenWidth() -> CGFloat {
        @Dependency(\.uiApplication.mainScreen) var mainScreen: UIScreen?
        return mainScreen?.bounds.width ?? UIScreen.main.bounds.width
    }

    // MARK: - View Builders

    private func buildSelectContactButton() -> UIButton? {
        guard let actionHandlerService = service?.actionHandler,
              let recipientBar else { return nil }

        let selectContactButton: UIButton = .init(type: .contactAdd)
        selectContactButton.tintColor = .accent

        selectContactButton.addTarget(
            actionHandlerService,
            action: #selector(actionHandlerService.selectContactButtonTapped),
            for: .touchUpInside
        )
        selectContactButton.isEnabled = false

        selectContactButton.frame.size.height = selectContactButton.intrinsicContentSize.height
        selectContactButton.frame.size.width = selectContactButton.intrinsicContentSize.width

        let xOriginOffset = recipientBar.frame.maxX - selectContactButton.intrinsicContentSize.width
        selectContactButton.frame.origin.x = xOriginOffset - Floats.selectContactButtonXOriginDecrement
        selectContactButton.center.y = recipientBar.center.y

        return selectContactButton
    }

    private func buildTableView() -> UITableView? {
        guard let superviewFrame = viewController.messagesCollectionView.superview?.frame else { return nil }
        let tableView: UITableView = .init(frame: superviewFrame)

        tableView.alpha = 0
        tableView.frame.origin.y += Floats.frameHeight
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Strings.tableViewCellReuseIdentifier)

        return tableView
    }

    private func buildTextField() -> UITextField? {
        guard let recipientBar,
              let service,
              let toLabel else { return nil }

        let textField: RecipientBarTextField = .init(frame: .init(
            origin: .zero,
            size: .init(width: screenWidth - Floats.textFieldWidthDecrement, height: Floats.frameHeight)
        ))
        textField.onSuperfluousBackspace { service.contactSelectionUI.onSuperflousBackspace() }

        textField.addTarget(
            service.actionHandler,
            action: #selector(service.actionHandler.textFieldChanged(_:)),
            for: .editingChanged
        )
        textField.delegate = recipientBar

        textField.center.x = recipientBar.center.x
        textField.frame.origin.x = toLabel.frame.maxX + Floats.textFieldXOriginIncrement

        textField.autocorrectionType = .no
        textField.keyboardType = .namePhonePad
        textField.spellCheckingType = .no

        return textField
    }

    private func buildToLabel() -> UILabel? {
        guard let recipientBar else { return nil }

        let toLabel: UILabel = .init(frame: .init(
            origin: .init(x: Floats.toLabelXOrigin, y: 0),
            size: .init(width: 0, height: Floats.frameHeight)
        ))

        toLabel.font = UIFont(name: Strings.toLabelFontName, size: Floats.toLabelFontSize)
        toLabel.text = Localized(.to).wrappedValue
        toLabel.textColor = .init(Colors.toLabelText)

        toLabel.frame.size.width = toLabel.intrinsicContentSize.width
        toLabel.center.y = recipientBar.center.y

        return toLabel
    }
}
