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
    // MARK: - Properties

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

    // MARK: - Init

    init(
        accountDeletion: AccountDeletionService,
        analytics: AnalyticsService,
        attributeDetection: AttributeDetectionService,
        audio: AudioService,
        breadcrumbsCapture: BreadcrumbsCaptureService,
        connectionStatus: ConnectionStatusService,
        contact: ContactService,
        contentPicker: ContentPickerService,
        documentExport: DocumentExportService,
        haptics: HapticsService,
        invite: InviteService,
        messageRecipientConsent: MessageRecipientConsentService,
        messageRetranslation: MessageRetranslationService,
        metadata: MetadataService,
        networkActivityIndicator: NetworkActivityIndicatorService,
        notification: NotificationService,
        penPals: PenPalsService,
        permission: PermissionService,
        phoneNumber: PhoneNumberService,
        propertyLists: CommonPropertyLists,
        pushToken: PushTokenService,
        regionDetail: RegionDetailService,
        remoteCache: RemoteCacheService,
        review: ReviewService,
        update: UpdateService
    ) {
        self.accountDeletion = accountDeletion
        self.analytics = analytics
        self.attributeDetection = attributeDetection
        self.audio = audio
        self.breadcrumbsCapture = breadcrumbsCapture
        self.connectionStatus = connectionStatus
        self.contact = contact
        self.contentPicker = contentPicker
        self.documentExport = documentExport
        self.haptics = haptics
        self.invite = invite
        self.messageRecipientConsent = messageRecipientConsent
        self.messageRetranslation = messageRetranslation
        self.metadata = metadata
        self.networkActivityIndicator = networkActivityIndicator
        self.notification = notification
        self.penPals = penPals
        self.permission = permission
        self.phoneNumber = phoneNumber
        self.propertyLists = propertyLists
        self.pushToken = pushToken
        self.regionDetail = regionDetail
        self.remoteCache = remoteCache
        self.review = review
        self.update = update
    }
}
