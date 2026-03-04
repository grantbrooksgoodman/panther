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

final class AttributeDetectionService {
    // MARK: - Properties

    static let shared = AttributeDetectionService()

    private var delegate: AttributeDetectionServiceDelegate? = DefaultAttributeDetectionServiceDelegate.shared

    // MARK: - Init

    private init() {}

    // MARK: - Register Delegate

    func registerDelegate(_ delegate: AttributeDetectionServiceDelegate) {
        self.delegate = delegate
    }

    // MARK: - Handle Gesture

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
        let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue |
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
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
