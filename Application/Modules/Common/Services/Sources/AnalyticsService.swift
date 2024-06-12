//
//  AnalyticsService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import FirebaseAnalytics

public struct AnalyticsService {
    // MARK: - Dependencies

    @Dependency(\.networking.config) private var networkConfig: NetworkConfig

    // MARK: - Types

    public enum AnalyticsEvent: String {
        /* MARK: Cases */

        case accessChat
        case deleteConversation
        case sendAudioMessage
        case sendTextMessage
        case viewAlternate

        case accessNewChatPage
        case createNewConversation
        case dismissNewChatPage
        case invite

        case clearCaches
        case logIn
        case logOut
        case signUp

        case openApp
        case closeApp
        case terminateApp

        /* MARK: Properties */

        public var name: String {
            rawValue.snakeCased
        }
    }

    private enum CommonParameter: String {
        /* MARK: Cases */

        case presentedViewName
        case serverEnvironment
        case storedLanguageCode

        /* MARK: Properties */

        public var keyValue: String {
            rawValue.snakeCased
        }
    }

    // MARK: - Properties

    private var commonParameters: [String: Any] {
        typealias Params = CommonParameter
        var params = [String: Any]()

        if let presentedViewName = RuntimeStorage.presentedViewName {
            params[Params.presentedViewName.keyValue] = presentedViewName
        }

        params[Params.serverEnvironment.keyValue] = networkConfig.environment.shortString
        params[Params.storedLanguageCode.keyValue] = RuntimeStorage.languageCode

        return params
    }

    // MARK: - Methods

    public func logEvent(_ event: AnalyticsEvent, extraParams: [String: Any]? = nil) {
        var parameters = commonParameters
        parameters.merge(commonParameters, uniquingKeysWith: { _, _ in })

        Analytics.logEvent(event.name, parameters: parameters)
    }
}
