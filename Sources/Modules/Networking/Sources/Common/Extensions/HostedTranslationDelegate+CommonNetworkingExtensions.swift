//
//  HostedTranslationDelegate+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

extension HostedTranslationDelegate {
    @discardableResult
    func addRecentlyUploadedLocalizedTranslationsToLocalArchive() async -> Exception? {
        @Dependency(\.translationArchiverDelegate) var localTranslationArchiver: TranslationArchiverDelegate
        @Dependency(\.networking) var networking: NetworkServices

        let languagePair: LanguagePair = .system
        let userInfo = ["LanguagePair": languagePair.string]

        guard !languagePair.isIdempotent else { return nil }

        if let exception = TranslationValidator.validate(
            languagePair: languagePair,
            metadata: .init(sender: self)
        ) {
            return exception.appending(userInfo: userInfo)
        }

        let queryValuesResult = await networking.database.queryValues(
            at: "\(NetworkPath.translations.rawValue)/\(languagePair.string)",
            strategy: .last(100)
        )

        switch queryValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: String] else {
                let exception: Exception = .Networking.typecastFailed("dictionary", metadata: .init(sender: self))
                return exception.appending(userInfo: userInfo)
            }

            for value in dictionary.values {
                guard let components = value.decodedTranslationComponents else {
                    return .Networking.decodingFailed(
                        data: value,
                        .init(sender: self)
                    ).appending(userInfo: userInfo)
                }

                let decoded: Translation = .init(
                    input: .init(components.input),
                    output: components.output,
                    languagePair: languagePair
                )
                localTranslationArchiver.addValue(decoded)

                Logger.log(
                    .init(
                        "Added hosted translation to local archive.",
                        isReportable: false,
                        userInfo: ["ReferenceHostingKey": decoded.reference.hostingKey],
                        metadata: .init(sender: self)
                    ),
                    domain: .Networking.hostedTranslation
                )
            }

            return nil

        case let .failure(exception):
            let exception = exception.appending(userInfo: userInfo)
            return .init(
                exception.descriptor,
                isReportable: false,
                userInfo: exception.userInfo,
                underlyingExceptions: exception.underlyingExceptions,
                metadata: exception.metadata
            )
        }
    }
}

private extension String {
    var decodedTranslationComponents: (input: String, output: String)? {
        let components = components(separatedBy: "–")
        guard components.count == 2,
              let inputString = components[0].removingPercentEncoding,
              let outputString = components[1].removingPercentEncoding else { return nil }
        return (inputString, outputString)
    }
}
