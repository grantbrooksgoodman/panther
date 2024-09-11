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
    convenience init(_ generalKey: UserDefaultsKey.GeneralAppDefaultsKey) {
        self.init(.general(generalKey))
    }

    convenience init(_ audioServiceKey: UserDefaultsKey.AudioServiceDefaultsKey) {
        self.init(.audioService(audioServiceKey))
    }

    convenience init(_ contactPairArchiveServiceKey: UserDefaultsKey.ContactPairArchiveServiceDefaultsKey) {
        self.init(.contactPairArchiveService(contactPairArchiveServiceKey))
    }

    convenience init(_ contactSyncServiceKey: UserDefaultsKey.ContactSyncServiceDefaultsKey) {
        self.init(.contactSyncService(contactSyncServiceKey))
    }

    convenience init(_ reviewServiceKey: UserDefaultsKey.ReviewServiceDefaultsKey) {
        self.init(.reviewService(reviewServiceKey))
    }

    convenience init(_ updateServiceKey: UserDefaultsKey.UpdateServiceDefaultsKey) {
        self.init(.updateService(updateServiceKey))
    }
}
