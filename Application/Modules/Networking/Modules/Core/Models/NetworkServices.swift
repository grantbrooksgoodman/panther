//
//  NetworkServices.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkServices {
    // MARK: - Properties

    public let translation: HostedTranslationService
    public let user: UserService

    // MARK: - Init

    public init(
        translation: HostedTranslationService,
        user: UserService
    ) {
        self.translation = translation
        self.user = user
    }
}
