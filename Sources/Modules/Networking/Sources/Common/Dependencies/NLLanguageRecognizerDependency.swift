//
//  NLLanguageRecognizerDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import NaturalLanguage

/* Proprietary */
import AppSubsystem

public enum NLLanguageRecognizerDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> NLLanguageRecognizer {
        .init()
    }
}

public extension DependencyValues {
    var nlLanguageRecognizer: NLLanguageRecognizer {
        get { self[NLLanguageRecognizerDependency.self] }
        set { self[NLLanguageRecognizerDependency.self] = newValue }
    }
}
