//
//  OnboardingServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum OnboardingServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> OnboardingService {
        .init()
    }
}

public extension DependencyValues {
    var onboardingService: OnboardingService {
        get { self[OnboardingServiceDependency.self] }
        set { self[OnboardingServiceDependency.self] = newValue }
    }
}
