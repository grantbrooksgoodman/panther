//
//  ChatInfoPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

// swiftlint:disable:next type_body_length
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
                        width: Floats.largeAvatarImageViewSizeWidth,
                        height: Floats.largeAvatarImageViewSizeHeight
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
                        Components.button(
                            viewModel.strings.value(for: .changeMetadataButtonText),
                            font: .system(scale: .custom(Floats.changeMetadataButtonLabelFontSize)),
                            foregroundColor: viewModel.isChangeMetadataButtonEnabled ? .accent : .disabled
                        ) {
                            viewModel.send(.changeMetadataButtonTapped)
                        }
                        .disabled(!viewModel.isChangeMetadataButtonEnabled)
                        .padding(.bottom, 1)
                        .padding(.horizontal, Floats.changeMetadataButtonHorizontalPadding)
                    }

                    listView
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

    // MARK: - List View

    private var listView: some View {
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
                            participantView(participant)
                        }
                        .dynamicTypeSize(.large)
                    } else {
                        Button {
                            viewModel.send(.penPalParticipantViewTapped(participant))
                        } label: {
                            participantView(participant)
                        }
                    }
                }
            }
        }
        .animation(.default, value: viewModel.visibleParticipants)
        .id(viewModel.viewID)
        .offset(y: Floats.listViewYOffset)
    }

    // MARK: - Participant View

    private func participantView(_ participant: ChatParticipant) -> some View {
        HStack(alignment: .center) {
            AvatarImageView(
                participant.thumbnailImage,
                size: .init(
                    width: Floats.smallAvatarImageViewSizeWidth,
                    height: Floats.smallAvatarImageViewSizeHeight
                )
            )
            .padding(.trailing, Floats.smallAvatarImageViewTrailingPadding)

            ThemedView {
                Group {
                    Components.text(
                        participant.displayName,
                        font: .systemSemibold
                    )

                    if let firstUser = participant.firstUser {
                        UserInfoBadgeView(
                            firstUser,
                            action: viewModel.isDeveloperModeEnabled ? { viewModel.send(.userInfoBadgeTapped(firstUser)) } : nil
                        )
                    }
                }
            }

            if participant.isPenPal {
                Spacer()

                if let firstUser = participant.firstUser,
                   viewModel.conversation?.currentUserSharesPenPalsData(with: firstUser) == true {
                    Components.symbol(
                        Strings.penPalsSharingStatusIconCompleteImageSystemName,
                        foregroundColor: Colors.penPalsSharingStatusIconCompleteForeground
                    )
                } else {
                    Components.symbol(
                        Strings.penPalsSharingStatusIconIncompleteImageSystemName,
                        foregroundColor: Colors.penPalsSharingStatusIconIncompleteForeground
                    )
                }
            }
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChatInfoPageViewStringKey) -> String {
        (first(where: { $0.key == .chatInfoPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
