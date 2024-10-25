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
    private typealias Strings = AppConstants.Strings.ChatPageViewService.RecipientBarService.ActionHandler

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
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
                coreGCD.after(.milliseconds(500)) {
                    Task { await self.services.permission.presentCTA(for: .contacts) }
                }
            }

            let selectContactButton = chatPageViewService.recipientBar?.layout.selectContactButton
            selectContactButton?.isEnabled = true

            guard services.permission.contactPermissionStatus == .granted else {
                let requestPermissionResult = await services.permission.requestPermission(for: .contacts)

                switch requestPermissionResult {
                case let .success(status):
                    guard status == .granted else {
                        presentCTA()
                        return
                    }

                    if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: true) { Logger.log(exception, with: .toast()) }
                    selectContactButtonTapped()

                case let .failure(exception):
                    guard !exception.isEqual(to: .contactAccessDenied) else {
                        presentCTA()
                        return
                    }

                    Logger.log(exception, with: .toast())
                }

                return
            }

            @Persistent(.contactPairArchive) var contactPairArchive: [ContactPair]?

            guard !(contactPairArchive ?? []).isEmpty else {
                selectContactButton?.isEnabled = false

                if let exception = await services.contact.sync.syncContactPairArchive(),
                   !exception.isEqual(to: .mismatchedHashAndCallingCode) {
                    Logger.log(exception, with: .toast())
                }

                guard (contactPairArchive ?? []).isEmpty else {
                    chatPageViewService.recipientBar?.tableView.resolveContactPairs()
                    selectContactButtonTapped()
                    return
                }

                let inviteAction: AKAction = .init(Strings.inviteAlertActionTitle, style: .preferred) {
                    Task {
                        if let exception = await self.services.invite.presentInvitationPrompt() {
                            Logger.log(exception, with: .toast())
                        }
                    }
                }

                await AKAlert(
                    message: Strings.inviteAlertMessage,
                    actions: [inviteAction, .cancelAction]
                ).present(translating: [.actions([inviteAction]), .message])

                selectContactButton?.isEnabled = true
                return
            }

            Observables.contactSelectorPresentationPending.trigger()
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
                guard !contactSelectionUIService.selectedContactPairs.filter({ $0.isMock }).isEmpty else {
                    contactSelectionUIService.unhighlightAllViews()
                    guard makeInputBarFirstResponder else { return }
                    self.chatPageViewService.inputBar?.becomeFirstResponder()
                    return
                }

                contactSelectionUIService.unhighlightAllViews()
                contactSelectionUIService.deselectMockContactPairs()
                coreGCD.after(.milliseconds(Floats.becomeFirstResponderDelayMilliseconds)) {
                    self.chatPageViewService.inputBar?.becomeFirstResponder()
                }
                return
            }

            let phoneNumber = PhoneNumber(text)
            guard !phoneNumber.compiledNumberString.isBlank,
                  text.digits.count == text.removingOccurrences(of: ["-", "+"]).trimmingWhitespace.count else {
                contactSelectionUIService.selectContactPair(.mock(withName: text))
                return
            }

            let getUsersResult = await userService.getUsers(phoneNumber: phoneNumber)

            switch getUsersResult {
            case let .success(users):
                guard let firstUser = users.first else { return } // TODO: Need action for multiple users.

                guard let contactPair = services.contact.contactPairArchive.getValue(phoneNumber: phoneNumber) else {
                    contactSelectionUIService.selectContactPair(.withUser(firstUser))
                    return
                }

                contactSelectionUIService.selectContactPair(contactPair)

            case .failure:
                contactSelectionUIService.selectContactPair(.mock(withName: text))
            }
        }
    }
}
