//
//  HostedTranslationServiceExceptions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum HostedTranslationServiceExceptions {
    public static func inputsFailValidation(
        extraParams: [String: Any],
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Input fails validation.",
            extraParams: extraParams,
            metadata: metadata
        )
    }

    public static func languagePairFailsValidation(
        extraParams: [String: Any],
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Language pair fails validation.",
            extraParams: extraParams,
            metadata: metadata
        )
    }

    public static func translationFailsValidation(
        extraParams: [String: Any],
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Translation fails validation.",
            extraParams: extraParams,
            metadata: metadata
        )
    }
}
