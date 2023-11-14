//
//  SampleViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Translator

public extension TranslatedLabelStringCollection {
    enum SampleViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        case titleLabelText = "Hello World"
        case subtitleLabelText = "In Redux!"

        public var alternate: String? { nil }
    }
}

public enum SampleViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.SampleViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .sampleView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
