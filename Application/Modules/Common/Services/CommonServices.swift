//
//  CommonServices.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct CommonServices {
    // MARK: - Properties

    public let analytics: AnalyticsService
    public let audio: AudioService
    public let contact: ContactService
    public let haptics: HapticsService
    public let invite: InviteService
    public let metadata: MetadataService
    public let networkActivityIndicator: NetworkActivityIndicatorService
    public let notification: NotificationService
    public let permission: PermissionService
    public let phoneNumber: PhoneNumberService
    public let propertyLists: CommonPropertyLists
    public let regionDetail: RegionDetailService
    public let review: ReviewService
    public let textMessage: TextMessageService
    public let update: UpdateService

    // MARK: - Init

    public init(
        analytics: AnalyticsService,
        audio: AudioService,
        contact: ContactService,
        haptics: HapticsService,
        invite: InviteService,
        metadata: MetadataService,
        networkActivityIndicator: NetworkActivityIndicatorService,
        notification: NotificationService,
        permission: PermissionService,
        phoneNumber: PhoneNumberService,
        propertyLists: CommonPropertyLists,
        regionDetail: RegionDetailService,
        review: ReviewService,
        textMessage: TextMessageService,
        update: UpdateService
    ) {
        self.analytics = analytics
        self.audio = audio
        self.contact = contact
        self.haptics = haptics
        self.invite = invite
        self.metadata = metadata
        self.networkActivityIndicator = networkActivityIndicator
        self.notification = notification
        self.permission = permission
        self.phoneNumber = phoneNumber
        self.propertyLists = propertyLists
        self.regionDetail = regionDetail
        self.review = review
        self.textMessage = textMessage
        self.update = update
    }
}
