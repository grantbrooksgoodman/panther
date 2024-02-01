//
//  Persistent+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Persistent {
    convenience init(_ generalKey: UserDefaultsKeyDomain.GeneralAppDefaultsKey) {
        self.init(.app(.general(generalKey)))
    }

    convenience init(_ audioServiceKey: UserDefaultsKeyDomain.AudioServiceDefaultsKey) {
        self.init(.app(.audioService(audioServiceKey)))
    }

    convenience init(_ contactPairArchiveServiceKey: UserDefaultsKeyDomain.ContactPairArchiveServiceDefaultsKey) {
        self.init(.app(.contactPairArchiveService(contactPairArchiveServiceKey)))
    }

    convenience init(_ contactSyncServiceKey: UserDefaultsKeyDomain.ContactSyncServiceDefaultsKey) {
        self.init(.app(.contactSyncService(contactSyncServiceKey)))
    }

    convenience init(_ reviewServiceKey: UserDefaultsKeyDomain.ReviewServiceDefaultsKey) {
        self.init(.app(.reviewService(reviewServiceKey)))
    }

    convenience init(_ updateServiceKey: UserDefaultsKeyDomain.UpdateServiceDefaultsKey) {
        self.init(.app(.updateService(updateServiceKey)))
    }
}
