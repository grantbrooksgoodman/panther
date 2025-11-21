//
//  RecipientBarActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem

public final class RecipientBarActionHandlerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.RecipientBarService.ActionHandler

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.userService) private var userService: UserService

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - On Superfluous Backspace

    public func onSuperflousBackspace() {
        guard let service = chatPageViewService.recipientBar else { return }

        /// - Returns: A boolean value indicating whether or not the view was configured for the given sublevels.
        func configureTextField(forSublevels sublevels: Int) -> Bool {
            func configureTextField(onSublevel sublevel: Int) -> Bool {
                guard let furthestTrailingView = service.config.firstContactView(.furthestTrailing(onSublevel: sublevel)) else { return false }
                service.config.reconfigureRecipientBar(forSublevel: sublevel)
                service.config.reconfigureTextField(relativeTo: furthestTrailingView)
                service.config.reconfigureCollectionView()
                return true
            }

            for sublevel in (1 ... sublevels).reversed() where configureTextField(onSublevel: sublevel) { return true }
            return false
        }

        guard let firstContactView = service.config.firstContactView(.onSameLevelAsTextField) else { return }
        guard service.contactSelectionUI.isHighlighted(viewID: firstContactView.identifier) else {
            service.contactSelectionUI.toggleIsHighlighted(viewID: firstContactView.identifier)
            return
        }

        service.contactSelectionUI.deselectContactPair(withViewID: firstContactView.identifier)

        guard !configureTextField(forSublevels: Int(Floats.sublevelCount)),
              let toLabel = service.layout.toLabel else { return }
        service.config.reconfigureTextField(relativeTo: toLabel)
        service.config.reconfigureCollectionView()
    }

    // MARK: - Selector Action Handlers

    @objc
    public func selectContactButtonTapped() {
        Task { @MainActor in
            func presentCTA() {
                core.gcd.after(.milliseconds(500)) {
                    Task { await self.services.permission.presentCTA(for: .contacts) }
                }
            }

            let selectContactButton = chatPageViewService.recipientBar?.layout.selectContactButton
            selectContactButton?.isEnabled = true
            defer { core.hud.hide(after: .seconds(1)) }

            guard services.permission.contactPermissionStatus == .granted else {
                let requestPermissionResult = await services.permission.requestPermission(for: .contacts)

                switch requestPermissionResult {
                case let .success(status):
                    guard status == .granted else {
                        presentCTA()
                        return
                    }

                    if let exception = await services.contact.syncContactPairArchive() { Logger.log(exception, with: .toast) }
                    selectContactButtonTapped()

                case let .failure(exception):
                    guard !exception.isEqual(to: .contactAccessDenied) else {
                        presentCTA()
                        return
                    }

                    Logger.log(exception, with: .toast)
                }

                return
            }

            @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?

            guard !(contactPairArchive ?? []).isEmpty else {
                selectContactButton?.isEnabled = false
                core.hud.showProgress(isModal: true)

                if let exception = await services.contact.syncContactPairArchive(),
                   !exception.isEqual(to: .mismatchedHashAndCallingCode) {
                    Logger.log(exception, with: .toast)
                }

                guard (contactPairArchive ?? []).isEmpty else {
                    chatPageViewService.recipientBar?.tableView.resolveContactPairs()
                    selectContactButtonTapped()
                    return
                }

                await services.invite.presentInvitationSuggestionPrompt()
                selectContactButton?.isEnabled = true
                return
            }

            navigation.navigate(to: .chat(.sheet(.contactSelector)))
        }
    }

    @objc
    public func textFieldChanged(_ textField: UITextField) {
        chatPageViewService.recipientBar?.tableView.setQuery(textField.text ?? "")
    }

    // MARK: - Text Field Should Return

    public func textFieldShouldReturn(_ text: String, makeInputBarFirstResponder: Bool = true) {
        Task { @MainActor in
            guard let contactSelectionUIService = chatPageViewService.recipientBar?.contactSelectionUI else { return }

            guard !text.isBlank else {
                guard !contactSelectionUIService.selectedContactPairs.filter(\.isMock).isEmpty else {
                    contactSelectionUIService.unhighlightAllViews()
                    guard makeInputBarFirstResponder else { return }
                    self.chatPageViewService.inputBar?.becomeFirstResponder()
                    return
                }

                contactSelectionUIService.unhighlightAllViews()
                contactSelectionUIService.deselectMockContactPairs()
                core.gcd.after(.milliseconds(Floats.becomeFirstResponderDelayMilliseconds)) {
                    self.chatPageViewService.inputBar?.becomeFirstResponder()
                }
                return
            }

            let phoneNumber = PhoneNumber(text)
            guard phoneNumber.compiledNumberString.count > 1,
                  text.digits.count == text.removingOccurrences(of: ["-", "+"]).trimmingWhitespace.count else {
                contactSelectionUIService.selectContactPair(.mock(withName: text))
                return
            }

            let getUserResult = await userService.getUser(phoneNumber: phoneNumber)

            switch getUserResult {
            case let .success(user):
                guard let contactPair = user.contactPair else {
                    contactSelectionUIService.selectContactPair(.withUser(user))
                    return
                }

                contactSelectionUIService.selectContactPair(contactPair)

            case .failure:
                contactSelectionUIService.selectContactPair(.mock(withName: text))
            }
        }
    }
}
