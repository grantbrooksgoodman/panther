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

protocol AttributeDetectionServiceDelegate: AnyObject {
    func didSelectDate(
        _ date: Date,
        at substring: String,
        inText fullText: String
    )

    func didSelectPhoneNumber(
        _ phoneNumber: String
    )

    func didSelectURL(
        _ url: URL,
        at substring: String,
        inText fullText: String
    )
}

@MainActor
final class DefaultAttributeDetectionServiceDelegate: @MainActor AttributeDetectionServiceDelegate {
    // MARK: - Dependencies

    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    static let shared = DefaultAttributeDetectionServiceDelegate()

    // MARK: - Init

    private init() {}

    // MARK: - Did Select Date

    func didSelectDate(
        _ date: Date,
        at substring: String,
        inText fullText: String
    ) {
        guard let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)") else { return }
        let nonEnglishTitle = "Show in the calendar"
        confirmSelection(
            RuntimeStorage.languageCode == "en" ? "Show in Calendar" : nonEnglishTitle,
            message: substring,
            fullText: fullText,
            url: url
        )
    }

    // MARK: - Did Select Phone Number

    func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "tel://\(phoneNumber.digits)") else { return }
        openURL(url)
    }

    // MARK: - Did Select URL

    func didSelectURL(
        _ url: URL,
        at substring: String,
        inText fullText: String
    ) {
        confirmSelection(
            "Open in \(RuntimeStorage.languageCode == "en" ? "Safari" : "browser")",
            message: substring,
            fullText: fullText,
            url: url
        )
    }

    // MARK: - Auxiliary

    private func confirmSelection(
        _ actionTitle: String,
        message: String,
        fullText: String,
        url: URL
    ) {
        Task { @MainActor in
            let matchingLabels = uiApplication
                .presentedViews
                .compactMap { $0 as? UILabel }
                .filter { $0.text == fullText }

            await AKActionSheet(
                message: message,
                actions: [.init(actionTitle) {
                    Task { @MainActor in
                        self.openURL(url)
                    }
                }],
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                sourceItem: .custom(.view(
                    matchingLabels.count > 1 ? nil : matchingLabels.first
                ))
            ).present(translating: [.actions([])])
        }
    }

    private func openURL(_ url: URL) {
        uiApplication.open(url)
    }
}
