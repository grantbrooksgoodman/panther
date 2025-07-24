//
//  ChatInfoPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct ChatInfoPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatInfoPageView
    private typealias Floats = AppConstants.CGFloats.ChatInfoPageView
    private typealias Strings = AppConstants.Strings.ChatInfoPageView

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ChatInfoPageObserver>
    @StateObject private var viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Bindings

    private var cameraPickerSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingCameraPickerSheet,
            sendAction: { .isPresentingCameraPickerSheetChanged($0, nil) }
        )
    }

    private var imagePickerSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingImagePickerSheet,
            sendAction: { .isPresentingImagePickerSheetChanged($0, nil) }
        )
    }

    private var isPenPalsSharingDataSwitchToggledBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPenPalsSharingDataSwitchToggled,
            sendAction: { _ in .penPalsSharingDataSwitchToggledOn }
        )
    }

    private var segmentedControlSelectionIndexBinding: Binding<Int> {
        viewModel.binding(
            for: \.segmentedControlSelectionIndex,
            sendAction: { .segmentedControlSelectionIndexChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - Body

    public var body: some View {
        StatefulView(
            viewModel.binding(for: \.viewState),
            progressPageViewBackgroundColor: .groupedContentBackground
        ) {
            ThemedView(
                navigationBarAppearance: Application.isInPrevaricationMode ? .appDefault : .default(),
                redrawsOnAppearanceChange: viewModel.singleCNContactContainer != nil,
                restoresNavigationBarAppearanceOnDisappear: false
            ) {
                NavigationWindow(
                    displayMode: .inline,
                    toolbarBackgroundColor: .navigationBarBackground,
                    toolbarItems: [doneToolbarButton]
                ) {
                    contentView
                        .id(viewModel.viewID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.groupedContentBackground)
                }
                .sheet(isPresented: cameraPickerSheetBinding) {
                    ContentPickerView<UIImage>(.camera) { image in
                        viewModel.send(.selectedImageChanged(image))
                    } onDismiss: { exception in
                        viewModel.send(.isPresentingCameraPickerSheetChanged(false, exception))
                    }
                }
                .sheet(isPresented: imagePickerSheetBinding) {
                    ContentPickerView<UIImage>(.photoLibrary) { image in
                        viewModel.send(.selectedImageChanged(image))
                    } onDismiss: { exception in
                        viewModel.send(.isPresentingImagePickerSheetChanged(false, exception))
                    }
                }
            }
        }
        .preferredStatusBarStyle(
            .conditionalLightContent,
            restoreOnDisappear: !Application.isInPrevaricationMode
        )
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
        .onDisappear {
            viewModel.send(.viewDisappeared)
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if let cnContactContainer = viewModel.singleCNContactContainer {
            CNContactView(
                cnContactContainer.cnContact,
                isUnknown: cnContactContainer.isUnknown
            )
            .offset(y: Floats.singleCNContactViewYOffset)
            .header(
                rightItem: headerRightItem,
                attributes: .init(
                    appearance: Application.isInPrevaricationMode ? .custom(backgroundColor: .navigationBarBackground) : .themed,
                    sizeClass: .sheet
                )
            )
        } else {
            VStack {
                AvatarImageView(
                    viewModel.avatarImage,
                    badgeCount: -1,
                    size: .init(
                        width: Floats.avatarImageViewSizeWidth,
                        height: Floats.avatarImageViewSizeHeight
                    )
                )
                .padding(.bottom, 1)
                .padding(.top, Floats.avatarImageViewTopPadding)
                .padding(.horizontal, Floats.avatarImageViewHorizontalPadding)

                Components.text(
                    viewModel.chatTitleLabelText,
                    font: .systemBold(scale: .large)
                )
                .multilineTextAlignment(.center)
                .padding(.bottom, 1)
                .padding(.horizontal, Floats.chatTitleLabelHorizontalPadding)

                if viewModel.showsPenPalsSharingDataSwitch {
                    ListRowView(.init(
                        .switch(isToggled: isPenPalsSharingDataSwitchToggledBinding),
                        innerText: viewModel.strings.value(for: .sharePhoneNumberListRowText)
                    ))
                    .padding(.horizontal, Floats.penPalsListRowViewHorizontalPadding)
                    .padding(.top, Floats.penPalsListRowViewTopPadding)
                    .disabled(viewModel.isPenPalsSharingDataSwitchToggled)
                } else {
                    if viewModel.showsChangeMetadataButton {
                        changeMetadataButton
                            .disabled(!viewModel.isChangeMetadataButtonEnabled)
                            .padding(.bottom, 1)
                            .padding(.horizontal, Floats.changeMetadataButtonHorizontalPadding)
                    }

                    ZStack {
                        VStack {
                            segmentedControlView

                            Group {
                                if viewModel.segmentedControlSelectionIndex == 0 {
                                    chatParticipantsList
                                } else {
                                    mediaItemList
                                }
                            }
                            .transition(
                                .opacity.animation(
                                    .easeIn(duration: Floats.listTransitionAnimationDuration)
                                )
                            )
                            .offset(
                                y: viewModel.mediaItemMetadata.isEmpty ? Floats.listViewYOffset : Floats.listViewAlternateYOffset
                            )
                            .zIndex(-1)
                        }
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Add Contact Button

    private var addContactButton: some View {
        Button {
            viewModel.send(.addContactButtonTapped)
        } label: {
            HStack {
                let imageView = Components.symbol(
                    Strings.addContactButtonImageSystemName,
                    foregroundColor: viewModel.isAddContactButtonEnabled ? .accent : .disabled,
                    usesIntrinsicSize: false
                ).frame(
                    width: Floats.addContactButtonImageWidth,
                    height: Floats.addContactButtonImageHeight
                )

                Circle()
                    .overlay(imageView, alignment: .center)
                    .frame(
                        maxWidth: Floats.addContactButtonCircleFrameMaxWidth,
                        maxHeight: Floats.addContactButtonCircleFrameMaxHeight
                    )
                    .foregroundStyle(ThemeService.isDarkModeActive ? Colors.addContactButtonCircleDarkForeground : Colors.addContactButtonCircleLightForeground)
                    .padding(.trailing, Floats.addContactButtonCircleTrailingPadding)

                Components.text(
                    viewModel.strings.value(for: .addContactButtonText),
                    foregroundColor: viewModel.isAddContactButtonEnabled ? .accent : .disabled
                )
            }
        }
    }

    // MARK: - Change Metadata Button

    @ViewBuilder
    private var changeMetadataButton: some View {
        let text = viewModel.strings.value(for: .changeMetadataButtonText) // swiftlint:disable:next line_length
        let font: ComponentKit.Font = UIApplication.v26FeaturesEnabled ? .systemSemibold(scale: .custom(Floats.changeMetadataButtonLabelFontSize)) : .system(scale: .custom(Floats.changeMetadataButtonLabelFontSize)) // swiftlint:disable:next line_length
        let foregroundColor = viewModel.isChangeMetadataButtonEnabled ? (UIApplication.v26FeaturesEnabled ? Color.background : Colors.changeMetadataButtonForeground) : .disabled

        if UIApplication.v26FeaturesEnabled {
            Components.capsuleButton(
                text,
                font: font,
                usesShadow: false
            ) { viewModel.send(.changeMetadataButtonTapped) }
        } else {
            Components.button(
                text,
                font: font,
                foregroundColor: foregroundColor
            ) { viewModel.send(.changeMetadataButtonTapped) }
        }
    }

    // MARK: - Chat Info Cell

    private var chatInfoCell: some View {
        Button {
            viewModel.send(.chatInfoCellTapped)
        } label: {
            ThemedView {
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Components.text(
                            viewModel.chatInfoCellTitleLabelText,
                            font: .systemSemibold
                        )
                        .padding(.bottom, 1)

                        Components.text(
                            viewModel.chatInfoCellSubtitleLabelText,
                            font: .system(scale: .custom(Floats.chatInfoCellSubtitleLabelFontSize)),
                            foregroundColor: .subtitleText
                        )
                        .lineLimit(1)
                    }

                    Spacer()

                    Components.symbol(
                        viewModel.chatInfoCellImageSystemName,
                        foregroundColor: .subtitleText
                    )
                }
            }
            .id(viewModel.chatInfoCellViewID)
        }
        .foregroundStyle(Color.titleText)
    }

    // MARK: - Done Toolbar Button

    private var doneToolbarButton: NavigationWindow.Toolbar.Item {
        .init(placement: .topBarTrailing) {
            if UIApplication.v26FeaturesEnabled {
                Components.v26DoneButton {
                    viewModel.send(.doneToolbarButtonTapped)
                }
            } else {
                Components.button(
                    viewModel.doneButtonText,
                    font: .systemSemibold,
                    foregroundColor: .navigationBarButton
                ) {
                    viewModel.send(.doneToolbarButtonTapped)
                }
            }
        }
    }

    // MARK: - Header Right Item

    private var headerRightItem: HeaderView.PeripheralButtonType {
        if UIApplication.v26FeaturesEnabled {
            return .v26DoneButton {
                viewModel.send(.doneHeaderItemTapped)
            }
        } else {
            return .doneButton(foregroundColor: .navigationBarButton) {
                viewModel.send(.doneHeaderItemTapped)
            }
        }
    }

    // MARK: - List Views

    private var chatParticipantsList: some View {
        List {
            ForEach(-1 ..< viewModel.visibleParticipants.count, id: \.self) { index in
                if index == -1 {
                    chatInfoCell
                } /* else if index == viewModel.visibleParticipants.count - 1 {
                     addContactButton
                         .disabled(!viewModel.isAddContactButtonEnabled)
                 } */ else if let participant = viewModel.visibleParticipants.itemAt(index) {
                    if let cnContactContainer = participant.cnContactContainer {
                        NavigationLink(
                            destination:
                            CNContactView(
                                cnContactContainer.cnContact,
                                isUnknown: cnContactContainer.isUnknown
                            )
                        ) {
                            ChatParticipantView(
                                participant,
                                userInfoBadgeViewAction: viewModel.isDeveloperModeEnabled ? {
                                    viewModel.send(.userInfoBadgeTapped(participant.firstUser))
                                } : nil
                            )
                        }
                        .dynamicTypeSize(.large)
                    } else {
                        Button {
                            viewModel.send(.penPalParticipantViewTapped(participant))
                        } label: {
                            ChatParticipantView(
                                participant,
                                userInfoBadgeViewAction: viewModel.isDeveloperModeEnabled ? {
                                    viewModel.send(.userInfoBadgeTapped(participant.firstUser))
                                } : nil
                            )
                        }
                    }
                }
            }
        }
        .animation(.default, value: viewModel.visibleParticipants)
    }

    private var mediaItemList: some View {
        List {
            ForEach(0 ..< viewModel.mediaItemMetadata.count, id: \.self) { index in
                if let mediaItemMetadata = viewModel.mediaItemMetadata.itemAt(index) {
                    MediaItemView(mediaItemMetadata) {
                        viewModel.send(.mediaItemViewTapped(mediaItemMetadata))
                    }
                }
            }
        }
    }

    // MARK: - Segmented Control View

    @ViewBuilder
    private var segmentedControlView: some View {
        if !viewModel.mediaItemMetadata.isEmpty {
            HStack {
                Picker("", selection: segmentedControlSelectionIndexBinding) {
                    ForEach(0 ..< viewModel.segmentedControlOptionTitles.count, id: \.self) { index in
                        if let segmentedControlOptionTitle = viewModel.segmentedControlOptionTitles.itemAt(index) {
                            Components.text(segmentedControlOptionTitle)
                        }
                    }
                }
                .id(viewModel.segmentedControlViewID)
                .pickerStyle(.segmented)
                .if(!viewModel.shouldElongateSegmentedControl) {
                    $0
                        .frame(maxWidth: viewModel.segmentedControlMaxWidth)
                        .fixedSize()
                }
                .padding(
                    viewModel.shouldElongateSegmentedControl ? .horizontal : .leading,
                    Floats.segmentedControlHorizontalOrLeadingPadding
                )
                .padding(.top, Floats.segmentedControlTopPadding)

                Spacer()
            }
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable file_length type_body_length
