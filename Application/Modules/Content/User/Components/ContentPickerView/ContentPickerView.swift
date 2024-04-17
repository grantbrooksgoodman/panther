//
//  ContentPickerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ContentPickerView<Content>: View {
    // MARK: - Properties

    private let source: ContentPickerContentSource
    private let onSelection: (Content) -> Void
    private let onDismiss: (Exception?) -> Void

    // MARK: - Init

    public init(
        _ source: ContentPickerContentSource,
        onSelection: @escaping (Content) -> Void,
        onDismiss: @escaping (Exception?) -> Void
    ) {
        self.source = source
        self.onSelection = onSelection
        self.onDismiss = onDismiss
    }

    // MARK: - View

    public var body: some View {
        switch source {
        case .camera:
            CameraPickerView { image in
                guard let content = image as? Content else {
                    onDismiss(.contentPickerContentTypeMismatch([self, #file, #function, #line]))
                    return
                }

                onSelection(content)
            } onDismiss: { exception in
                onDismiss(exception)
            }

        case .photoLibrary:
            PhotoPickerView { image in
                guard let content = image as? Content else {
                    onDismiss(.contentPickerContentTypeMismatch([self, #file, #function, #line]))
                    return
                }

                onSelection(content)
            } onDismiss: { exception in
                onDismiss(exception)
            }
        }
    }
}
