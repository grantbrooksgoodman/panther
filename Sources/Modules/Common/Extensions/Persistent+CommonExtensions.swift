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
    /// Creates a persistent value bound to the given ``Application`` storage key.
    ///
    /// - Parameter applicationKey: The key that identifies the stored value.
    convenience init(
        _ applicationKey: PersistentStorageKey.ApplicationStorageKey
    ) {
        self.init(.application(applicationKey))
    }

    /// Creates a persistent value bound to the given ``AIEnhancedTranslationService`` storage
    /// key.
    ///
    /// - Parameter aiEnhancedTranslationServiceKey: The key that identifies the stored value.
    convenience init(
        _ aiEnhancedTranslationServiceKey: PersistentStorageKey.AIEnhancedTranslationServiceStorageKey
    ) {
        self.init(.aiEnhancedTranslationService(aiEnhancedTranslationServiceKey))
    }

    /// Creates a persistent value bound to the given ``AudioService`` storage key.
    ///
    /// - Parameter audioServiceKey: The key that identifies the stored value.
    convenience init(
        _ audioServiceKey: PersistentStorageKey.AudioServiceStorageKey
    ) {
        self.init(.audioService(audioServiceKey))
    }

    /// Creates a persistent value bound to the given ``BreadcrumbsCaptureService`` storage key.
    ///
    /// - Parameter breadcrumbsCaptureServiceKey: The key that identifies the stored value.
    convenience init(
        _ breadcrumbsCaptureServiceKey: PersistentStorageKey.BreadcrumbsCaptureServiceStorageKey
    ) {
        self.init(.breadcrumbsCaptureService(breadcrumbsCaptureServiceKey))
    }

    /// Creates a persistent value bound to the given ``ContactPairArchiveService`` storage key.
    ///
    /// - Parameter contactPairArchiveServiceKey: The key that identifies the stored value.
    convenience init(
        _ contactPairArchiveServiceKey: PersistentStorageKey.ContactPairArchiveServiceStorageKey
    ) {
        self.init(.contactPairArchiveService(contactPairArchiveServiceKey))
    }

    /// Creates a persistent value bound to the given ``MessageRetranslationService`` storage key.
    ///
    /// - Parameter messageRetranslationServiceKey: The key that identifies the stored value.
    convenience init(
        _ messageRetranslationServiceKey: PersistentStorageKey.MessageRetranslationServiceStorageKey
    ) {
        self.init(.messageRetranslationService(messageRetranslationServiceKey))
    }

    /// Creates a persistent value bound to the given ``PenPalsService`` storage key.
    ///
    /// - Parameter penPalsServiceKey: The key that identifies the stored value.
    convenience init(
        _ penPalsServiceKey: PersistentStorageKey.PenPalsServiceStorageKey
    ) {
        self.init(.penPalsService(penPalsServiceKey))
    }

    /// Creates a persistent value bound to the given ``ReviewService`` storage key.
    ///
    /// - Parameter reviewServiceKey: The key that identifies the stored value.
    convenience init(
        _ reviewServiceKey: PersistentStorageKey.ReviewServiceStorageKey
    ) {
        self.init(.reviewService(reviewServiceKey))
    }

    /// Creates a persistent value bound to the given ``UpdateService`` storage key.
    ///
    /// - Parameter updateServiceKey: The key that identifies the stored value.
    convenience init(
        _ updateServiceKey: PersistentStorageKey.UpdateServiceStorageKey
    ) {
        self.init(.updateService(updateServiceKey))
    }
}
