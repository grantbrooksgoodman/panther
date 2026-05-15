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

struct ChatInfoPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatInfoPageView
    private typealias Floats = AppConstants.CGFloats.ChatInfoPageView
    private typealias Strings = AppConstants.Strings.ChatInfoPageView

    // MARK: - Dependencies

    @ObservedDependency(\.navigation) private var navigation: Navigation

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ChatInfoPageObserver>
    @StateObject private var viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Bindings

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

    private var sheetBinding: Binding<ChatNavigatorState.SheetPaths?> {
        navigation.navigable(
            \.chat.sheet,
            route: { .chat(.sheet($0)) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - Body

    var body: some View {
        StatefulView(
            viewModel.binding(for: \.viewState),
            progressPageViewBackgroundColor: .groupedContentBackground
        ) {
            ThemedView {
                contentView
                    .id(viewModel.viewID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.groupedContentBackground)
                    .header(
                        rightItem: headerRightItem,
                        attributes: .init(
                            restoreOnDisappear: false, // TODO: Shouldn't be necessary.
                            sizeClass: .sheet
                        ),
                        usesV26Attributes: !Application.isInPrevaricationMode
                    )
                    .sheet(item: sheetBinding) { sheetView(for: $0) }
                    .if(!UIApplication.isFullyV26Compatible) { contentView in
                        NavigationWindow(
                            displayMode: .inline,
                            toolbarItems: [doneToolbarButton]
                        ) {
                            contentView
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

                                ListRowView(.init(
                                    .button { viewModel.send(.leaveConversationButtonTapped) },
                                    innerText: viewModel.strings.value(for: .leaveConversation),
                                    innerTextColor: Colors.leaveConversationListRowViewForeground,
                                    isEnabled: viewModel.isLeaveConversationButtonEnabled
                                ))
                                .disabled(!viewModel.isLeaveConversationButtonEnabled)
                                .padding(
                                    .horizontal,
                                    Floats.leaveConversationListRowViewHorizontalPadding
                                )
                                .redrawsOnTraitCollectionChange()
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
            ThemedView {
                HStack {
                    let imageView = Components.symbol(
                        Strings.addContactButtonImageSystemName,
                        foregroundColor: viewModel.isAddContactButtonEnabled ? Colors.addContactButtonSymbolForeground : .disabled,
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
                        .foregroundStyle(
                            ThemeService.isDarkModeActive ? Colors.addContactButtonCircleDarkForeground : Colors.addContactButtonCircleLightForeground
                        )
                        .padding(.trailing, Floats.addContactButtonCircleTrailingPadding)

                    Components.text(
                        viewModel.strings.value(for: .addContactButtonText),
                        foregroundColor: viewModel.isAddContactButtonEnabled ? Colors.addContactButtonLabelForeground : .disabled
                    )
                }
            }
        }
        .disabled(!viewModel.isAddContactButtonEnabled)
    }

    // MARK: - Change Metadata Button

    @ViewBuilder
    private var changeMetadataButton: some View {
        let text = viewModel.strings.value(for: .changeMetadataButtonText) // swiftlint:disable:next line_length
        let font: ComponentKit.Font = UIApplication.isFullyV26Compatible ? .systemSemibold(scale: .custom(Floats.changeMetadataButtonLabelFontSize)) : .system(scale: .custom(Floats.changeMetadataButtonLabelFontSize)) // swiftlint:disable:next line_length
        let foregroundColor = viewModel.isChangeMetadataButtonEnabled ? (UIApplication.isFullyV26Compatible ? Color.background : Colors.changeMetadataButtonForeground) : .disabled

        if UIApplication.isFullyV26Compatible {
            Components.capsuleButton(
                text,
                font: font,
                usesShadow: false,
                isInspectable: true
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
            if UIApplication.isFullyV26Compatible {
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
        if UIApplication.isFullyV26Compatible {
            .v26DoneButton {
                viewModel.send(.doneHeaderItemTapped)
            }
        } else {
            .doneButton(foregroundColor: .navigationBarButton) {
                viewModel.send(.doneHeaderItemTapped)
            }
        }
    }

    // MARK: - List Views

    private var chatParticipantsList: some View {
        List {
            ForEach(
                -1 ..< (viewModel.visibleParticipants.count + viewModel.visibleParticipantsIncrement),
                id: \.self
            ) { index in
                if index == -1 {
                    chatInfoCell
                } else if index == viewModel.visibleParticipants.count {
                    addContactButton
                } else if let participant = viewModel.visibleParticipants.itemAt(index) {
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
                                deleteAction: viewModel.showsRemoveUserSwipeAction ? {
                                    viewModel.send(.removeUserButtonTapped(participant))
                                } : nil,
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
                                deleteAction: viewModel.showsRemoveUserSwipeAction ? {
                                    viewModel.send(.removeUserButtonTapped(participant))
                                } : nil,
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

    // MARK: - Auxiliary

    @ViewBuilder
    private func sheetView(for path: ChatNavigatorState.SheetPaths) -> some View {
        switch path {
        case .cameraPicker:
            ContentPickerView<UIImage>(.camera) { image in
                viewModel.send(.selectedImageChanged(image))
            } onDismiss: { exception in
                viewModel.send(.cameraPickerDismissed(exception))
            }

        case .contactSelector:
            ContactSelectorPageView(.init(
                initialState: .init(.chatInfoPageView),
                reducer: ContactSelectorPageReducer()
            ))

        case .photoPicker:
            ContentPickerView<UIImage>(.photoLibrary) { image in
                viewModel.send(.selectedImageChanged(image))
            } onDismiss: { exception in
                viewModel.send(.photoPickerDismissed(exception))
            }
        }
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}

// swiftlint:enable file_length type_body_length
