//
//  HostedTranslationService+AKTranslationDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import Translator

extension HostedTranslationService: AlertKit.TranslationDelegate {
    public func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair,
        hud hudConfig: AlertKit.HUDConfig?,
        timeout timeoutConfig: AlertKit.TranslationTimeoutConfig
    ) async -> Result<[Translation], TranslationError> {
        var hudConfigTuple: (Duration, Bool)?
        if let hudConfig {
            hudConfigTuple = (hudConfig.appearsAfter, hudConfig.isModal)
        }

        let getTranslationsResult = await getTranslations(
            for: inputs,
            languagePair: languagePair,
            hud: hudConfigTuple
        )

        switch getTranslationsResult {
        case let .success(translations):
            return .success(translations)

        case let .failure(exception):
            return .failure(.unknown(exception.descriptor))
        }
    }
}
