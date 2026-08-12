//
//  AttributeDetectionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/11/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/// Use ``AttributeDetectionService`` to handle taps on attributes detected in text.
///
/// The service detects dates, links, and phone numbers in a label's attributed text and
/// notifies its delegate when the user taps one. Register your own conformance with
/// ``registerDelegate(_:)`` to customize how selections are handled; otherwise,
/// ``DefaultAttributeDetectionServiceDelegate`` is used.
@MainActor
final class AttributeDetectionService {
    // MARK: - Properties

    /// The shared attribute detection service instance.
    static let shared = AttributeDetectionService()

    private var delegate: AttributeDetectionServiceDelegate? = DefaultAttributeDetectionServiceDelegate.shared

    // MARK: - Init

    private init() {}

    // MARK: - Register Delegate

    /// Registers the delegate that handles attribute selections.
    ///
    /// Registering a new delegate replaces any existing one.
    ///
    /// - Parameter delegate: The delegate to register.
    func registerDelegate(_ delegate: AttributeDetectionServiceDelegate) {
        self.delegate = delegate
    }

    // MARK: - Handle Gesture

    /// Handles a tap on the given label, notifying the delegate if the touch falls on a
    /// detected attribute.
    ///
    /// This method hit-tests the touch location against the label's attributed text to find the
    /// tapped character, then matches dates, links, and phone numbers in the text. If the
    /// tapped character falls within a match, the corresponding delegate method is called.
    ///
    /// - Parameters:
    ///   - view: The view containing the label, whose origin offsets the touch location.
    ///   - label: The label whose attributed text to inspect.
    ///   - touchLocation: The location of the touch.
    func handleGesture(
        in view: UIView,
        label: UILabel,
        at touchLocation: CGPoint
    ) {
        guard let attributedText = label.attributedText,
              attributedText.length > 0 else { return }

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: label.bounds.size)
        let textStorage = NSTextStorage(attributedString: attributedText)

        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        var touchLocationInLabel = touchLocation
        touchLocationInLabel.x -= view.frame.minX
        touchLocationInLabel.y -= view.frame.minY

        let glyphIndex = layoutManager.glyphIndex(for: touchLocationInLabel, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        let range = NSRange(location: 0, length: attributedText.length)
        let dataDetector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue |
                NSTextCheckingResult.CheckingType.link.rawValue |
                NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        )
        let matches = dataDetector?.matches(in: attributedText.string, options: [], range: range) ?? []

        for match in matches where match.range.contains(characterIndex) {
            guard let range = Range(
                match.range,
                in: attributedText.string
            ) else { continue }

            switch match.resultType {
            case .date:
                guard let date = match.date else { continue }
                delegate?.didSelectDate(
                    date,
                    at: .init(attributedText.string[range]),
                    inText: attributedText.string
                )

            case .link:
                guard let url = match.url else { continue }
                delegate?.didSelectURL(
                    url,
                    at: .init(attributedText.string[range]),
                    inText: attributedText.string
                )

            case .phoneNumber:
                guard let phoneNumber = match.phoneNumber else { continue }
                delegate?.didSelectPhoneNumber(phoneNumber)

            default: continue
            }
        }
    }
}
