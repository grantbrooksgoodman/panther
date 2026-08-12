//
//  MediaItemView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 21/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A row describing a media file in a conversation's media list.
///
/// Use ``MediaItemView`` to display a media file's thumbnail, type, sender, and timestamp.
/// Tapping the row performs the given action; a long press previews the file and offers to
/// save it – images and videos to the photo library, and other files through the system
/// document picker.
struct MediaItemView: View {
    // MARK: - Types

    /// The display metadata for a media item.
    struct Metadata: Hashable {
        /* MARK: Properties */

        /// The media file the item describes.
        let file: MediaFile

        /// The text the media type label displays.
        let mediaTypeLabelText: String

        /// The text the sender label displays.
        let senderLabelText: String

        /// The text the timestamp label displays.
        let timestampLabelText: String

        /* MARK: Init */

        /// Creates media item metadata.
        ///
        /// - Parameters:
        ///   - file: The media file the item describes.
        ///   - mediaTypeLabelText: The text the media type label displays.
        ///   - senderLabelText: The text the sender label displays.
        ///   - timestampLabelText: The text the timestamp label displays.
        init(
            _ file: MediaFile,
            mediaTypeLabelText: String,
            senderLabelText: String,
            timestampLabelText: String
        ) {
            self.file = file
            self.mediaTypeLabelText = mediaTypeLabelText
            self.senderLabelText = senderLabelText
            self.timestampLabelText = timestampLabelText
        }
    }

    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.MediaItemView
    private typealias Floats = AppConstants.CGFloats.MediaItemView
    private typealias Strings = AppConstants.Strings.MediaItemView

    // MARK: - Dependencies

    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.commonServices.documentExport) private var documentExportService: DocumentExportService

    // MARK: - Properties

    private let action: () -> Void
    private let metadata: Metadata

    // MARK: - Init

    /// Creates a media item row.
    ///
    /// - Parameters:
    ///   - metadata: The display metadata for the item.
    ///   - action: The action performed when the user taps the row.
    init(
        _ metadata: Metadata,
        action: @escaping () -> Void
    ) {
        self.metadata = metadata
        self.action = action
    }

    // MARK: - Body

    /// The content and behavior of the view.
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(uiImage: metadata.file.image ?? .missing)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: Floats.imageFrameWidth,
                        height: Floats.imageFrameHeight
                    )
                    .cornerRadius(Floats.imageCornerRadius)

                VStack(alignment: .leading, spacing: 0) {
                    ThemedView {
                        Components.text(
                            metadata.mediaTypeLabelText,
                            font: .systemSemibold
                        )
                    }

                    Components.text(
                        metadata.senderLabelText,
                        font: .system(scale: .small),
                        foregroundColor: Colors.senderLabelForeground
                    )
                    .padding(.top, 1)
                }

                Spacer()

                Components.text(
                    metadata.timestampLabelText,
                    font: .system(scale: .small),
                    foregroundColor: Colors.timestampLabelForeground
                )
            }
        }
        .contextMenu {
            Button {
                saveFile()
            } label: {
                Label(
                    Localized(.saveFile).wrappedValue,
                    systemImage: Strings.saveActionImageSystemName
                )
            }
        } preview: {
            Image(uiImage: metadata.file.image ?? .missing)
                .resizable()
                .scaledToFit()
        }
    }

    // MARK: - Auxiliary

    @MainActor
    private func saveFile() {
        if metadata.file.fileExtension.isImage,
           let image = metadata.file.image(.full) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            coreHUD.showSuccess()
        } else if metadata.file.fileExtension.isVideo {
            UISaveVideoAtPathToSavedPhotosAlbum(metadata.file.localPathURL.path(), nil, nil, nil)
            coreHUD.showSuccess()
        } else {
            do {
                try documentExportService.presentExportController(
                    forFileAt: metadata.file.localPathURL
                )

                documentExportService.onDismiss { cancelled in
                    guard !cancelled else { return }
                    coreHUD.showSuccess()
                }
            } catch {
                Logger.log(
                    error,
                    with: .toast
                )
            }
        }
    }
}
