//
//  UIImage+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

public extension UIImage {
    // MARK: - Type Aliases

    private typealias Strings = AppConstants.Strings.UserContentExtensions.UIImage

    // MARK: - Properties

    static var missing: UIImage {
        let config: UIImage.SymbolConfiguration = .init(
            pointSize: 100,
            weight: .regular,
            scale: .medium
        )

        return .init(
            systemName: Strings.missingImageSystemName,
            withConfiguration: config
        )?.withTintColor(
            .systemGray3,
            renderingMode: .alwaysOriginal
        ).withAlignmentRectInsets(
            .init(
                top: 0,
                left: 0,
                bottom: 0,
                right: 0
            )
        ) ?? .init()
    }

    // MARK: - Methods

    func dataCompressed(toKB kilobytes: Int, toleratedMarginOfError: CGFloat = 0.2) -> Data? {
        var compressedData: Data?
        var currentKilobytes = kilobytes

        while compressedData == nil {
            compressedData = _dataCompressed(toKB: currentKilobytes, toleratedMarginOfError: toleratedMarginOfError)
            currentKilobytes -= 1
            guard currentKilobytes > 1 else { break }
        }

        return compressedData
    }

    func resized(toPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let imageSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            draw(in: .init(origin: .zero, size: imageSize))
        }
    }

    static func fromInitials(
        _ initials: String,
        backgroundColor: UIColor = .systemGray,
        font: UIFont = .systemFont(ofSize: 20),
        textColor: UIColor = .white,
        size: CGSize = .init(width: 50, height: 50)
    ) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        let graphicsContext = UIGraphicsGetCurrentContext()
        graphicsContext?.setFillColor(backgroundColor.cgColor)
        graphicsContext?.fill(.init(origin: .zero, size: size))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]

        let textSize = initials.size(withAttributes: textAttributes)
        let textFrame = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        initials.draw(in: textFrame, withAttributes: textAttributes)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func _dataCompressed(toKB kilobytes: Int, toleratedMarginOfError: CGFloat) -> Data? {
        let bytes = kilobytes * 1024
        let step: CGFloat = 0.05

        var currentCompression: CGFloat = 1.0
        var currentImage = self
        var didComplete = false

        while !didComplete {
            guard currentCompression > 0 else { break }

            if let data = currentImage.jpegData(compressionQuality: 1.0) {
                guard !(data.count < Int(CGFloat(bytes) * (1 + toleratedMarginOfError))) else {
                    didComplete = true
                    return data
                }

                let ratio = data.count / bytes
                let multiplier = CGFloat((ratio / 5) + 1)
                currentCompression -= (step * multiplier)
            }

            guard let newImage = currentImage.resized(toPercentage: currentCompression) else { break }
            currentImage = newImage
        }

        return nil
    }
}
