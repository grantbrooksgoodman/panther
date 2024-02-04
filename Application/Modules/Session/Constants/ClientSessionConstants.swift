//
//  ClientSessionConstants.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum ClientSessionConstants {
    public static let addMessageDeliveryProgressIncrement: Float = 0.2 // swiftlint:disable:next identifier_name
    public static let createConversationDeliveryProgressIncrement: Float = 0.2
    public static let createMessageDeliveryProgressIncrement: Float = 0.2
    public static let notifyDeliveryProgressIncrement: Float = 0.2
    public static let readToFileDeliveryProgressIncrement: Float = 0.05
    public static let translationDeliveryProgressIncrement: Float = 0.05
    public static let updateValueDeliveryProgressIncrement: Float = 0.2
}
