// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import BraveShared
import BraveCore
import BraveUI
import Shared
import SwiftKeychainWrapper
import SwiftUI

// MARK: - Callouts

extension BrowserViewController {

  func presentPassCodeMigration() {
    if KeychainWrapper.sharedAppContainerKeychain.authenticationInfo() != nil {
      let controller = UIHostingController(rootView: PasscodeMigrationContainerView())
      controller.rootView.dismiss = { [unowned controller] enableBrowserLock in
        KeychainWrapper.sharedAppContainerKeychain.setAuthenticationInfo(nil)
        Preferences.Privacy.lockWithPasscode.value = enableBrowserLock
        controller.dismiss(animated: true)
      }
      controller.modalPresentationStyle = .overFullScreen
      // No animation to ensure we don't leak the users tabs
      present(controller, animated: false)
    }
  }

//  func presentDefaultBrowserScreenCallout() {
//    if Preferences.DebugFlag.skipNTPCallouts == true || isOnboardingOrFullScreenCalloutPresented { return }
//
//    if presentedViewController != nil || !FullScreenCalloutManager.shouldShowDefaultBrowserCallout(calloutType: .defaultBrowser) {
//      return
//    }
//
//    let onboardingController = WelcomeViewController(
//      profile: nil,
//      state: WelcomeViewCalloutState.defaultBrowserCallout(
//        info: WelcomeViewCalloutState.WelcomeViewDefaultBrowserDetails(
//          title: Strings.Callout.defaultBrowserCalloutTitle,
//          details: Strings.Callout.defaultBrowserCalloutDescription,
//          primaryButtonTitle: Strings.Callout.defaultBrowserCalloutPrimaryButtonTitle,
//          secondaryButtonTitle: Strings.Callout.defaultBrowserCalloutSecondaryButtonTitle,
//          primaryAction: { [weak self] in
//            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
//              return
//            }
//
//            Preferences.General.defaultBrowserCalloutDismissed.value = true
//            UIApplication.shared.open(settingsUrl)
//            self?.dismiss(animated: false)
//          },
//          secondaryAction: { [weak self] in
//            self?.dismiss(animated: false)
//          }
//        )
//      )
//    )
//
//    present(onboardingController, animated: true)
//    isOnboardingOrFullScreenCalloutPresented = true
//  }
}
