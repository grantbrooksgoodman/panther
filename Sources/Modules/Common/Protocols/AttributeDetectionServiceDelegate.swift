//
//  AttributeDetectionServiceDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

public protocol AttributeDetectionServiceDelegate: AnyObject {
    func didSelectDate(_ date: Date)
    func didSelectPhoneNumber(_ phoneNumber: String)
    func didSelectURL(_ url: URL)
}

public final class DefaultAttributeDetectionServiceDelegate: AttributeDetectionServiceDelegate {
    // MARK: - Dependencies

    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public static let shared = DefaultAttributeDetectionServiceDelegate()

    // MARK: - Init

    private init() {}

    // MARK: - Did Select Date

    public func didSelectDate(_ date: Date) {
        guard let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)") else { return }
        didSelectURL(url)
    }

    // MARK: - Did Select Phone Number

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "tel://\(phoneNumber.digits)") else { return }
        didSelectURL(url)
    }

    // MARK: - Did Select URL

    public func didSelectURL(_ url: URL) {
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }
}
