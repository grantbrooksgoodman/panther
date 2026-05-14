//
//  SamplePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    enum SamplePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case titleLabelText = "Hello World"
        case subtitleLabelText = "In Redux!"

        // MARK: - Properties

        var alternate: String? {
            nil
        }
    }
}

enum SamplePageViewStrings: TranslatedLabelStrings {
    static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.SamplePageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .samplePageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
