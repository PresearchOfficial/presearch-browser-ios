// Copyright 2021 The Presearch Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SwiftUI
import struct Shared.Strings
import BraveUI

public struct WalletSettingsView: View {
  @ObservedObject var settingsStore: SettingsStore
  @ObservedObject var networkStore: NetworkStore
  @ObservedObject var keyringStore: KeyringStore

  @State private var isShowingResetWalletAlert = false
  @State private var isShowingResetTransactionAlert = false
  /// If we are showing the modal so the user can enter their password to enable unlock via biometrics.
  @State private var isShowingBiometricsPasswordEntry = false

  public init(
    settingsStore: SettingsStore,
    networkStore: NetworkStore,
    keyringStore: KeyringStore
  ) {
    self.settingsStore = settingsStore
    self.networkStore = networkStore
    self.keyringStore = keyringStore
  }

  private var autoLockIntervals: [AutoLockInterval] {
    var all = AutoLockInterval.allOptions
    if !all.contains(settingsStore.autoLockInterval) {
      // Ensure that the users selected interval always appears as an option even if
      // we remove it from `allOptions`
      all.append(settingsStore.autoLockInterval)
    }
    return all.sorted(by: { $0.value < $1.value })
  }

  public var body: some View {
    List {
      Section(
        footer: Text(Strings.Wallet.autoLockFooter)
          .foregroundColor(Color(.secondaryBraveLabel))
      ) {
        Picker(selection: $settingsStore.autoLockInterval) {
          ForEach(autoLockIntervals) { interval in
            Text(interval.label)
              .foregroundColor(Color(.secondaryBraveLabel))
              .tag(interval)
          }
        } label: {
          Text(Strings.Wallet.autoLockTitle)
            .foregroundColor(Color(.braveLabel))
            .padding(.vertical, 4)
        }
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
      if settingsStore.isBiometricsAvailable, keyringStore.keyring.isKeyringCreated {
        Section(
          footer: Text(Strings.Wallet.settingsEnableBiometricsFooter)
            .foregroundColor(Color(.secondaryBraveLabel))
        ) {
          Toggle(
            Strings.Wallet.settingsEnableBiometricsTitle,
            isOn: Binding(get: { settingsStore.isBiometricsUnlockEnabled },
                          set: { toggledBiometricsUnlock($0) })
          )
            .foregroundColor(Color(.braveLabel))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
        .listRowBackground(Color(.secondaryBraveGroupedBackground))
      }
      Section(
        footer: Text(Strings.Wallet.networkFooter)
          .foregroundColor(Color(.secondaryBraveLabel))
      ) {
        NavigationLink(destination: CustomNetworkListView(networkStore: networkStore)) {
          Text(Strings.Wallet.settingsNetworkButtonTitle)
            .foregroundColor(Color(.braveLabel))
        }
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
      Section(
        footer: Text(Strings.Wallet.settingsResetTransactionFooter)
          .foregroundColor(Color(.secondaryBraveLabel))
      ) {
        Button(action: { isShowingResetTransactionAlert = true }) {
          Text(Strings.Wallet.settingsResetTransactionTitle)
            .foregroundColor(Color(.braveBlurpleTint))
        }
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
      Section {
        Button(action: { isShowingResetWalletAlert = true }) {
          Text(Strings.Wallet.settingsResetButtonTitle)
            .foregroundColor(.red)
        }
        // iOS 15: .role(.destructive)
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
    }
    .listStyle(InsetGroupedListStyle())
    .navigationTitle(Strings.Wallet.braveWallet)
    .navigationBarTitleDisplayMode(.inline)
    .background(
      Color.clear
        .alert(isPresented: $isShowingResetTransactionAlert) {
          Alert(
            title: Text(Strings.Wallet.settingsResetTransactionAlertTitle),
            message: Text(Strings.Wallet.settingsResetTransactionAlertMessage),
            primaryButton: .destructive(
              Text(Strings.Wallet.settingsResetTransactionAlertButtonTitle),
              action: {
                settingsStore.resetTransaction()
              }),
            secondaryButton: .cancel(Text(Strings.cancelButtonTitle))
          )
        }
    )
    .background(
      Color.clear
        .alert(isPresented: $isShowingResetWalletAlert) {
          Alert(
            title: Text(Strings.Wallet.settingsResetWalletAlertTitle),
            message: Text(Strings.Wallet.settingsResetWalletAlertMessage),
            primaryButton: .destructive(
              Text(Strings.Wallet.settingsResetWalletAlertButtonTitle),
              action: {
                settingsStore.reset()
              }),
            secondaryButton: .cancel(Text(Strings.no))
          )
        }
    )
    .background(
      Color.clear
        .sheet(isPresented: $isShowingBiometricsPasswordEntry) {
          BiometricsPasscodeEntryView(keyringStore: keyringStore)
        }
    )
  }
  
  private func toggledBiometricsUnlock(_ enabled: Bool) {
    if enabled {
      self.isShowingBiometricsPasswordEntry = true
    } else {
      KeyringStore.resetKeychainStoredPassword()
    }
  }
}

#if DEBUG
struct WalletSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      WalletSettingsView(
        settingsStore: .previewStore,
        networkStore: .previewStore,
        keyringStore: .previewStore
      )
    }
  }
}
#endif
