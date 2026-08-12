//
//  CommonServices.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// The umbrella container for the app's common services.
///
/// Use ``CommonServices`` to access shared, feature-agnostic services from a single dependency.
struct CommonServices: @unchecked Sendable {
    /// The service that permanently deletes the current user's account.
    let accountDeletion: AccountDeletionService

    /// The service that records the user's choice about AI-enhanced translation.
    let aiEnhancedTranslation: AIEnhancedTranslationService

    /// The service that reports usage events to the analytics backend.
    let analytics: AnalyticsService

    /// The service that handles taps on attributes detected in text.
    let attributeDetection: AttributeDetectionService

    /// The umbrella service for audio functionality.
    let audio: AudioService

    /// The service that periodically captures screenshots of novel view hierarchies for
    /// diagnostic purposes.
    let breadcrumbsCapture: BreadcrumbsCaptureService

    /// The service that runs effects when network connectivity changes.
    let connectionStatus: ConnectionStatusService

    /// The service that matches the user's device contacts with registered users.
    let contact: ContactService

    /// The umbrella service for content picking.
    let contentPicker: ContentPickerService

    /// The service that exports files with the system document picker.
    let documentExport: DocumentExportService

    /// The service that plays haptic feedback.
    let haptics: HapticsService

    /// The service that invites the user's contacts to the app.
    let invite: InviteService

    /// The service that manages the message recipient consent flow.
    let messageRecipientConsent: MessageRecipientConsentService

    /// The service that retranslates messages whose translations may be incorrect.
    let messageRetranslation: MessageRetranslationService

    /// The service that reads app configuration values hosted in the remote database.
    let metadata: MetadataService

    /// The delegate that styles and controls the network activity indicator.
    let networkActivityIndicator: NetworkActivityIndicatorService

    /// The service that sends push notifications and responds to notifications received while
    /// the app is in the foreground.
    let notification: NotificationService

    /// The service that manages the PenPals feature.
    let penPals: PenPalsService

    /// The service that checks, requests, and prompts for system permissions.
    let permission: PermissionService

    /// The service that derives calling codes, hashes, and formatting details from phone
    /// number strings.
    let phoneNumber: PhoneNumberService

    /// The service that reads phone number reference data bundled with the app as property
    /// lists.
    let propertyLists: CommonPropertyLists

    /// The service that manages the device push notification tokens registered for users.
    let pushToken: PushTokenService

    /// The service that looks up region details – names, titles, calling codes, and images –
    /// for the regions in the app's phone number reference data.
    let regionDetail: RegionDetailService

    /// The service that reads and writes the remote cache status of individual users.
    let remoteCache: RemoteCacheService

    /// The service that requests App Store reviews at appropriate moments.
    let review: ReviewService

    /// The service that prompts the user to install app updates.
    let update: UpdateService
}
