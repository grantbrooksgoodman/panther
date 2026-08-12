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

/// The interface used to handle taps on attributes detected in text.
///
/// ``AttributeDetectionService`` detects dates, links, and phone numbers in a label's attributed
/// text and notifies its delegate when the user taps one. Register your own conformance with
/// ``AttributeDetectionService/registerDelegate(_:)`` to customize how selections are handled;
/// otherwise, ``DefaultAttributeDetectionServiceDelegate`` is used.
protocol AttributeDetectionServiceDelegate: AnyObject {
    /// Tells the delegate that the user selected a date in the given text.
    ///
    /// - Parameters:
    ///   - date: The date that was selected.
    ///   - substring: The portion of the text in which the date was detected.
    ///   - fullText: The complete text containing the detected date.
    func didSelectDate(
        _ date: Date,
        at substring: String,
        inText fullText: String
    )

    /// Tells the delegate that the user selected a phone number.
    ///
    /// - Parameter phoneNumber: The phone number that was selected.
    func didSelectPhoneNumber(
        _ phoneNumber: String
    )

    /// Tells the delegate that the user selected a URL in the given text.
    ///
    /// - Parameters:
    ///   - url: The URL that was selected.
    ///   - substring: The portion of the text in which the URL was detected.
    ///   - fullText: The complete text containing the detected URL.
    func didSelectURL(
        _ url: URL,
        at substring: String,
        inText fullText: String
    )
}

/// The delegate used by ``AttributeDetectionService`` when no custom delegate is registered.
///
/// The default delegate presents a confirmation action sheet for date and URL selections – opening
/// the Calendar app or the system browser if the user confirms – and opens phone number selections
/// immediately as `tel` links.
@MainActor
final class DefaultAttributeDetectionServiceDelegate: @MainActor AttributeDetectionServiceDelegate {
    // MARK: - Dependencies

    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    /// The shared default delegate instance.
    static let shared = DefaultAttributeDetectionServiceDelegate()

    // MARK: - Init

    private init() {}

    // MARK: - Did Select Date

    /// Presents an action sheet offering to show the selected date in the Calendar app.
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

    /// Opens the selected phone number as a `tel` link.
    func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "tel://\(phoneNumber.digits)") else { return }
        openURL(url)
    }

    // MARK: - Did Select URL

    /// Presents an action sheet offering to open the selected URL in the system browser.
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
