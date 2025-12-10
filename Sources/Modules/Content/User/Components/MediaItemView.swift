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

struct MediaItemView: View {
    // MARK: - Types

    struct Metadata: Hashable {
        /* MARK: Properties */

        let file: MediaFile
        let mediaTypeLabelText: String
        let senderLabelText: String
        let timestampLabelText: String

        /* MARK: Init */

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

    init(
        _ metadata: Metadata,
        action: @escaping () -> Void
    ) {
        self.metadata = metadata
        self.action = action
    }

    // MARK: - Body

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
            let exception = documentExportService.presentExportController(forFileAt: metadata.file.localPathURL)
            documentExportService.onDismiss { cancelled in
                guard !cancelled else { return }
                guard let exception else { return coreHUD.showSuccess() }
                Logger.log(exception, with: .toast)
            }
        }
    }
}
