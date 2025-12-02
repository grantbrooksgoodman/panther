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

struct CommonServices {
    let accountDeletion: AccountDeletionService
    let analytics: AnalyticsService
    let attributeDetection: AttributeDetectionService
    let audio: AudioService
    let breadcrumbsCapture: BreadcrumbsCaptureService
    let connectionStatus: ConnectionStatusService
    let contact: ContactService
    let contentPicker: ContentPickerService
    let documentExport: DocumentExportService
    let haptics: HapticsService
    let invite: InviteService
    let messageRecipientConsent: MessageRecipientConsentService
    let messageRetranslation: MessageRetranslationService
    let metadata: MetadataService
    let networkActivityIndicator: NetworkActivityIndicatorService
    let notification: NotificationService
    let penPals: PenPalsService
    let permission: PermissionService
    let phoneNumber: PhoneNumberService
    let propertyLists: CommonPropertyLists
    let pushToken: PushTokenService
    let regionDetail: RegionDetailService
    let remoteCache: RemoteCacheService
    let review: ReviewService
    let update: UpdateService
}
