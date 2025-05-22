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
import AlertKit
import AppSubsystem

public protocol AttributeDetectionServiceDelegate: AnyObject {
    func didSelectDate(_ date: Date, inText text: String)
    func didSelectPhoneNumber(_ phoneNumber: String)
    func didSelectURL(_ url: URL, inText text: String)
}

public final class DefaultAttributeDetectionServiceDelegate: AttributeDetectionServiceDelegate {
    // MARK: - Dependencies

    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public static let shared = DefaultAttributeDetectionServiceDelegate()

    // MARK: - Init

    private init() {}

    // MARK: - Did Select Date

    public func didSelectDate(_ date: Date, inText text: String) {
        guard let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)") else { return }
        let nonEnglishTitle = "Show in the calendar"
        confirmSelection(
            RuntimeStorage.languageCode == "en" ? "Show in Calendar" : nonEnglishTitle,
            text: text,
            url: url
        )
    }

    // MARK: - Did Select Phone Number

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "tel://\(phoneNumber.digits)") else { return }
        openURL(url)
    }

    // MARK: - Did Select URL

    public func didSelectURL(_ url: URL, inText text: String) {
        confirmSelection(
            "Open in \(RuntimeStorage.languageCode == "en" ? "Safari" : "browser")",
            text: text,
            url: url
        )
    }

    // MARK: - Auxiliary

    private func confirmSelection(
        _ actionTitle: String,
        text: String,
        url: URL
    ) {
        Task {
            await AKActionSheet(
                message: text,
                actions: [.init(actionTitle) { self.openURL(url) }],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions([])])
        }
    }

    private func openURL(_ url: URL) {
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }
}
