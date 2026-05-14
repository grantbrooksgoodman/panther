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

extension Persistent {
    convenience init(
        _ applicationKey: PersistentStorageKey.ApplicationStorageKey
    ) {
        self.init(.application(applicationKey))
    }

    convenience init(
        _ aiEnhancedTranslationServiceKey: PersistentStorageKey.AIEnhancedTranslationServiceStorageKey
    ) {
        self.init(.aiEnhancedTranslationService(aiEnhancedTranslationServiceKey))
    }

    convenience init(
        _ audioServiceKey: PersistentStorageKey.AudioServiceStorageKey
    ) {
        self.init(.audioService(audioServiceKey))
    }

    convenience init(
        _ breadcrumbsCaptureServiceKey: PersistentStorageKey.BreadcrumbsCaptureServiceStorageKey
    ) {
        self.init(.breadcrumbsCaptureService(breadcrumbsCaptureServiceKey))
    }

    convenience init(
        _ contactPairArchiveServiceKey: PersistentStorageKey.ContactPairArchiveServiceStorageKey
    ) {
        self.init(.contactPairArchiveService(contactPairArchiveServiceKey))
    }

    convenience init(
        _ messageRetranslationServiceKey: PersistentStorageKey.MessageRetranslationServiceStorageKey
    ) {
        self.init(.messageRetranslationService(messageRetranslationServiceKey))
    }

    convenience init(
        _ penPalsServiceKey: PersistentStorageKey.PenPalsServiceStorageKey
    ) {
        self.init(.penPalsService(penPalsServiceKey))
    }

    convenience init(
        _ reviewServiceKey: PersistentStorageKey.ReviewServiceStorageKey
    ) {
        self.init(.reviewService(reviewServiceKey))
    }

    convenience init(
        _ updateServiceKey: PersistentStorageKey.UpdateServiceStorageKey
    ) {
        self.init(.updateService(updateServiceKey))
    }
}
