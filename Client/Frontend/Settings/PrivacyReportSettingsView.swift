// Copyright 2022 The Presearch Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SwiftUI
import Shared
import BraveShared

struct PrivacyReportSettingsView: View {
  
  @ObservedObject private var shieldsDataEnabled = Preferences.PrivacyReports.captureShieldsData
  @ObservedObject private var vpnAlertsEnabled = Preferences.PrivacyReports.captureVPNAlerts
  
  @State private var clearButtonEnabled: Bool = true
  
  var body: some View {
    List {
      Section(footer: Text(Strings.PrivacyHub.settingsEnableShieldsFooter)) {
        Toggle(Strings.PrivacyHub.settingsEnableShieldsTitle, isOn: $shieldsDataEnabled.value)
          .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
      
      Section(footer: Text(Strings.PrivacyHub.settingsEnableVPNAlertsFooter)) {
        Toggle(Strings.PrivacyHub.settingsEnableVPNAlertsTitle, isOn: $vpnAlertsEnabled.value)
          .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
      
      Section(footer: Text(Strings.PrivacyHub.settingsSlearDataFooter)) {
        HStack() {
          Button(action: {
            PrivacyReportsManager.clearAllData()
            clearButtonEnabled = false
          },
                 label: {
            Text(Strings.PrivacyHub.settingsSlearDataTitle)
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundColor(Color.red)
          })
            .disabled(!clearButtonEnabled)
        }
      }
      .listRowBackground(Color(.secondaryBraveGroupedBackground))
      
      // MARK: - Mini debug section.
      if !AppConstants.buildChannel.isPublic {
        Section(footer: Text("This will force all data to consolidate. All stats for 'last 7 days' should be cleared and 'all time data' views should be preserved.")) {
          HStack() {
            Button(action: {
              Preferences.PrivacyReports.nextConsolidationDate.value = Date().advanced(by: -2.days)
              PrivacyReportsManager.consolidateData(dayRange: -10)
            },
                   label: {
              Text("[Debug] - Consolidate data")
                .frame(maxWidth: .infinity, alignment: .leading)
            })
          }
        }
        .listRowBackground(Color(.secondaryBraveGroupedBackground))
      }
    }
    .listStyle(.insetGrouped)
  }
}

#if DEBUG
struct PrivacyReportSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    PrivacyReportSettingsView()
  }
}
#endif
