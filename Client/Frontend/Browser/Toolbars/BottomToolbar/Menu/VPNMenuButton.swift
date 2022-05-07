// Copyright 2021 The Presearch Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Shared
import SwiftUI
import BraveUI

/// A menu button that provides a shortcut to toggling Presearch VPN
struct VPNMenuButton: View {
  /// The product info
  var vpnProductInfo: VPNProductInfo
  /// The description for product info
  var description: String?
  /// A closure executed when the parent must display a VPN-specific view controller due to some
  /// user action
  var displayVPNDestination: (UIViewController) -> Void
  /// A closure executed when VPN is toggled and status is installed. This will be used to set
  /// current activity for user
  var enableInstalledVPN: () -> Void

  @State private var isVPNStatusChanging: Bool = BraveVPN.reconnectPending
  @State private var isVPNEnabled = BraveVPN.isConnected
  @State private var isErrorShowing: Bool = false

  private var isVPNEnabledBinding: Binding<Bool> {
    Binding(
      get: { isVPNEnabled },
      set: { toggleVPN($0) }
    )
  }

  private func toggleVPN(_ enabled: Bool) {
  }

  private var vpnToggle: some View {
    Group {
      let toggle = Toggle("Presearch VPN", isOn: isVPNEnabledBinding)
      if #available(iOS 14.0, *) {
        toggle
          .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      } else {
        toggle
      }
    }
  }

  var body: some View {
    HStack {
      MenuItemHeaderView(
        icon: #imageLiteral(resourceName: "vpn_menu_icon").template,
        title: description == nil ? "Presearch VPN" : Strings.OptionsMenu.braveVPNItemTitle,
        subtitle: description)
      Spacer()
      if isVPNStatusChanging {
        ActivityIndicatorView(isAnimating: true)
      }
      vpnToggle
        .labelsHidden()
    }
    .padding(.horizontal, 14)
    .frame(maxWidth: .infinity, minHeight: 48.0, alignment: .leading)
    .background(
      Button(action: { toggleVPN(!BraveVPN.isConnected) }) {
        Color.clear
      }
      .buttonStyle(TableCellButtonStyle())
    )
    .accessibilityElement()
    .accessibility(addTraits: .isButton)
    .accessibility(label: Text("Presearch VPN"))
    .alert(isPresented: $isErrorShowing) {
      Alert(
        title: Text(verbatim: Strings.VPN.errorCantGetPricesTitle),
        message: Text(verbatim: Strings.VPN.errorCantGetPricesBody),
        dismissButton: .default(Text(verbatim: Strings.OKString))
      )
    }
    .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
      isVPNEnabled = BraveVPN.isConnected
      isVPNStatusChanging = BraveVPN.reconnectPending
    }
  }
}
