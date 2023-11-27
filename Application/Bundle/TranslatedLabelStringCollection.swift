//
//  TranslatedLabelStringCollection.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum TranslatedLabelStringCollection: Equatable {
    /* Add cases here to expose new strings for on-the-fly translation. */

    case sampleView(SampleViewStringKey)
    case welcomePageView(WelcomePageViewStringKey)
}
