//
//  SplashPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import Redux

public struct SplashPageViewService {
    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.build) private var build: Build
    @Dependency(\.networking.services.translation) private var hostedTranslationService: HostedTranslationService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Methods

    public func initializeBundle() async -> Exception? {
        /* MARK: AKCore Delegate Setup */

        akCore.register(reportDelegate: ErrorReportingService())
        akCore.register(translationDelegate: hostedTranslationService)

        /* MARK: MetadataService Setup */

        if let exception = await services.metadata.resolveValues() {
            return exception
        }

        /* MARK: ReviewService Setup */

        services.review.incrementAppOpenCount()

        /* MARK: UpdateService Setup */

        services.update.incrementRelaunchCountIfNeeded()
        if let exception = await services.update.promptToUpdateIfNeeded() {
            return exception
        }

        /* MARK: UserSessionService Setup */

        let setCurrentUserResult = await userSession.setCurrentUser()

        switch setCurrentUserResult {
        case .success:
            guard let currentUser = userSession.currentUser else {
                return .init("Failed to set current user.", metadata: [self, #file, #function, #line])
            }

            akCore.setLanguageCode(currentUser.languageCode)
            RuntimeStorage.store(currentUser.languageCode, as: .languageCode)

            if let exception = await currentUser.setConversations() {
                return exception
            }

            if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
                return exception
            }

            if let exception = await services.notification.setBadgeNumber(currentUser.badgeNumber) {
                return exception
            }

            var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 4 == 0 }
            @Persistent(.didClearCaches) var didClearCaches: Bool?
            let mustUpdateContactPairArchive = didClearCaches ?? false
            didClearCaches = nil

            if !mustUpdateContactPairArchive {
                guard randomBool, randomBool, randomBool else { return nil }
            }

            if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: mustUpdateContactPairArchive || (randomBool && randomBool)),
               !exception.isEqual(to: .notAuthorizedForContacts) {
                return exception
            }

            return nil

        case let .failure(exception):
            guard !exception.isEqual(to: .currentUserIDNotSet) else { return nil }
            return exception
        }
    }

    /// - Returns: An integer describing the selected action ID.
    public func presentErrorAlert(_ exception: Exception) async -> Int {
        let akError = AKError(exception)
        let mockGenericException = Exception(metadata: [self, #file, #function, #line])
        let mockTimedOutException = Exception.timedOut([self, #file, #function, #line])

        let notGenericDescription = akError.description != mockGenericException.userFacingDescriptor
        let notTimedOutDescription = akError.description != mockTimedOutException.userFacingDescriptor
        let hasUserFacingDescriptor = akError.extraParams?.keys.contains(Exception.CommonParamKeys.userFacingDescriptor.rawValue) ?? false

        let shouldTranslate = hasUserFacingDescriptor && notGenericDescription && notTimedOutDescription
        var translationOptionKeys: [AKTranslationOptionKey] = [build.isOnline ? .actions(indices: nil) : .none]
        if shouldTranslate,
           build.isOnline {
            translationOptionKeys = [.actions(indices: nil), .message]
        }

        let errorAlert = AKErrorAlert(
            error: akError,
            cancelButtonTitle: Localized(.tryAgain).wrappedValue,
            shouldTranslate: translationOptionKeys
        )

        return await errorAlert.present()
    }
}
