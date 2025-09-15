//
//  Persistent+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Persistent {
    convenience init(_ applicationKey: UserDefaultsKey.ApplicationDefaultsKey) {
        self.init(.application(applicationKey))
    }

    convenience init(_ audioServiceKey: UserDefaultsKey.AudioServiceDefaultsKey) {
        self.init(.audioService(audioServiceKey))
    }

    convenience init(_ breadcrumbsCaptureServiceKey: UserDefaultsKey.BreadcrumbsCaptureServiceDefaultsKey) {
        self.init(.breadcrumbsCaptureService(breadcrumbsCaptureServiceKey))
    }

    convenience init(_ contactPairArchiveServiceKey: UserDefaultsKey.ContactPairArchiveServiceDefaultsKey) {
        self.init(.contactPairArchiveService(contactPairArchiveServiceKey))
    }

    convenience init(_ penPalsServiceKey: UserDefaultsKey.PenPalsServiceDefaultsKey) {
        self.init(.penPalsService(penPalsServiceKey))
    }

    convenience init(_ reviewServiceKey: UserDefaultsKey.ReviewServiceDefaultsKey) {
        self.init(.reviewService(reviewServiceKey))
    }

    convenience init(_ updateServiceKey: UserDefaultsKey.UpdateServiceDefaultsKey) {
        self.init(.updateService(updateServiceKey))
    }
}
