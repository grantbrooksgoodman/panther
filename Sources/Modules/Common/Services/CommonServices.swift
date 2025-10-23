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

public struct CommonServices {
    // MARK: - Properties

    public let analytics: AnalyticsService
    public let attributeDetection: AttributeDetectionService
    public let audio: AudioService
    public let breadcrumbsCapture: BreadcrumbsCaptureService
    public let connectionStatus: ConnectionStatusService
    public let contact: ContactService
    public let contentPicker: ContentPickerService
    public let documentExport: DocumentExportService
    public let haptics: HapticsService
    public let invite: InviteService
    public let messageRecipientConsent: MessageRecipientConsentService
    public let messageRetranslation: MessageRetranslationService
    public let metadata: MetadataService
    public let networkActivityIndicator: NetworkActivityIndicatorService
    public let notification: NotificationService
    public let penPals: PenPalsService
    public let permission: PermissionService
    public let phoneNumber: PhoneNumberService
    public let propertyLists: CommonPropertyLists
    public let pushToken: PushTokenService
    public let regionDetail: RegionDetailService
    public let remoteCache: RemoteCacheService
    public let review: ReviewService
    public let textMessage: TextMessageService
    public let update: UpdateService

    // MARK: - Init

    public init(
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
        textMessage: TextMessageService,
        update: UpdateService
    ) {
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
        self.textMessage = textMessage
        self.update = update
    }
}
