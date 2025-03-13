//
//  UIImage+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public extension UIImage {
    // MARK: - Type Aliases

    private typealias Strings = AppConstants.Strings.UserContentExtensions.UIImage

    // MARK: - Properties

    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: Strings.averageColorCoreImageFilterName,
            parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: extentVector,
            ]
        ),
            let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let coreImageContext = CIContext(options: [.workingColorSpace: kCFNull as Any])
        coreImageContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(
                bitmap[0]
            ) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: CGFloat(bitmap[3]) / 255
        )
    }

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
