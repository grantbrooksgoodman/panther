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
import Redux

public struct CommonServices {
    // MARK: - Properties

    public let analytics: AnalyticsService
    public let audio: AudioService
    public let contact: ContactService
    public let invite: InviteService
    public let metadata: MetadataService
    public let permission: PermissionService
    public let phoneNumber: PhoneNumberService
    public let propertyLists: CommonPropertyLists
    public let regionDetail: RegionDetailService
    public let review: ReviewService
    public let textMessage: TextMessageService
    public let update: UpdateService
    public let userSession: UserSessionService

    // MARK: - Init

    public init(
        analytics: AnalyticsService,
        audio: AudioService,
        contact: ContactService,
        invite: InviteService,
        metadata: MetadataService,
        permission: PermissionService,
        phoneNumber: PhoneNumberService,
        propertyLists: CommonPropertyLists,
        regionDetail: RegionDetailService,
        review: ReviewService,
        textMessage: TextMessageService,
        update: UpdateService,
        userSession: UserSessionService
    ) {
        self.analytics = analytics
        self.audio = audio
        self.contact = contact
        self.invite = invite
        self.metadata = metadata
        self.permission = permission
        self.phoneNumber = phoneNumber
        self.propertyLists = propertyLists
        self.regionDetail = regionDetail
        self.review = review
        self.textMessage = textMessage
        self.update = update
        self.userSession = userSession
    }
}
