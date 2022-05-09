/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared
import BraveShared
import Static
import SwiftKeychainWrapper
import LocalAuthentication
import SwiftyJSON
import Data
import WebKit
import BraveCore
import SwiftUI
import BraveWallet

extension TabBarVisibility: RepresentableOptionType {
  public var displayString: String {
    switch self {
    case .always: return Strings.alwaysShow
    case .landscapeOnly: return Strings.showInLandscapeOnly
    case .never: return Strings.neverShow
    }
  }
}

extension DataSource {
  /// Get the index path of a Row to modify it
  ///
  /// Since they are structs we cannot obtain references to them to alter them, we must directly access them
  /// from `sections[x].rows[y]`
  func indexPath(rowUUID: String, sectionUUID: String) -> IndexPath? {
    guard let section = sections.firstIndex(where: { $0.uuid == sectionUUID }),
      let row = sections[section].rows.firstIndex(where: { $0.uuid == rowUUID })
    else {
      return nil
    }
    return IndexPath(row: row, section: section)
  }

  func reloadCell(row: Row, section: Static.Section, displayText: String) {
    if let indexPath = indexPath(rowUUID: row.uuid, sectionUUID: section.uuid) {
      sections[indexPath.section].rows[indexPath.row].detailText = displayText
    }
  }
}

protocol SettingsDelegate: AnyObject {
  func settingsOpenURLInNewTab(_ url: URL)
  func settingsOpenURLs(_ urls: [URL])
  func settingsDidFinish(_ settingsViewController: SettingsViewController)
}

class SettingsViewController: TableViewController {
  weak var settingsDelegate: SettingsDelegate?

  private let profile: Profile
  private let tabManager: TabManager
  private let rewards: BraveRewards?
  private let legacyWallet: BraveLedger?
  private let feedDataSource: FeedDataSource
  private let historyAPI: BraveHistoryAPI
  private let passwordAPI: BravePasswordAPI
  private let syncAPI: BraveSyncAPI
  private let walletSettingsStore: SettingsStore?
  private let walletNetworkStore: NetworkStore?
  private let keyringStore: KeyringStore?
  private let windowProtection: WindowProtection?

  private let featureSectionUUID: UUID = .init()
  private let walletRowUUID: UUID = .init()

  init(
    profile: Profile,
    tabManager: TabManager,
    feedDataSource: FeedDataSource,
    rewards: BraveRewards? = nil,
    legacyWallet: BraveLedger? = nil,
    windowProtection: WindowProtection?,
    braveCore: BraveCoreMain,
    walletSettingsStore: SettingsStore? = nil,
    walletNetworkStore: NetworkStore? = nil,
    keyringStore: KeyringStore? = nil
  ) {
    self.profile = profile
    self.tabManager = tabManager
    self.feedDataSource = feedDataSource
    self.rewards = rewards
    self.legacyWallet = legacyWallet
    self.windowProtection = windowProtection
    self.historyAPI = braveCore.historyAPI
    self.passwordAPI = braveCore.passwordAPI
    self.syncAPI = braveCore.syncAPI
    self.walletSettingsStore = walletSettingsStore
    self.walletNetworkStore = walletNetworkStore
    self.keyringStore = keyringStore

    super.init(style: .insetGrouped)
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = Strings.settings
    tableView.accessibilityIdentifier = "SettingsViewController.tableView"
    setUpSections()

    tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)

    view.backgroundColor = .braveGroupedBackground
    view.tintColor = .braveOrange
  }

  private func displayRewardsDebugMenu() {
    guard let rewards = rewards else { return }
    let settings = RewardsDebugSettingsViewController(rewards: rewards, legacyWallet: legacyWallet)
    navigationController?.pushViewController(settings, animated: true)
  }

  private func displayBraveNewsDebugMenu() {
    let settings = UIHostingController(rootView: BraveNewsDebugSettingsView(dataSource: feedDataSource))
    navigationController?.pushViewController(settings, animated: true)
  }

  private func displayBraveSearchDebugMenu() {
    let hostingController =
      UIHostingController(rootView: BraveSearchDebugMenu(logging: BraveSearchLogEntry.shared))

    navigationController?.pushViewController(hostingController, animated: true)
  }

  // Do not use `sections` directly to access sections/rows. Use DataSource.sections instead.
  private var sections: [Static.Section] {
    var list = [
      defaultBrowserSection,
      featuresSection,
      generalSection,
      displaySection,
      securitySection,
      supportSection,
      aboutSection,
    ]

    if let debugSection = debugSection {
      list.append(debugSection)
    }

    return list
  }

  // MARK: - Sections

  private lazy var enableBraveVPNSection: Static.Section = {
    let header = EnableVPNSettingHeader()
//    header.enableVPNTapped = { [weak self] in
//      self?.enableVPNTapped()
//    }

    header.dismissHeaderTapped = { [weak self] in
      self?.dismissVPNHeaderTapped()
    }

    let calculatedSize = header.systemLayoutSizeFitting(
      CGSize(width: navigationController?.navigationBar.frame.width ?? 0, height: 300),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )

    header.bounds = CGRect(size: calculatedSize)

    return Static.Section(header: .view(header))
  }()

  private lazy var defaultBrowserSection: Static.Section = {
    var section = Static.Section(
      rows: [
        .init(
          text: Strings.setDefaultBrowserSettingsCell,
          selection: { [unowned self] in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
              return
            }
            UIApplication.shared.open(settingsUrl)
          }, cellClass: MultilineButtonCell.self)
      ]
    )

    return section
  }()

  private lazy var featuresSection: Static.Section = {
    var section = Static.Section(
      header: .title(Strings.features),
      rows: [
        Row(
          text: Strings.braveShieldsAndPrivacy,
          selection: { [unowned self] in
            let controller = BraveShieldsAndPrivacySettingsController(
              profile: self.profile,
              tabManager: self.tabManager,
              feedDataSource: self.feedDataSource,
              historyAPI: self.historyAPI)
            self.navigationController?.pushViewController(controller, animated: true)
          }, image: #imageLiteral(resourceName: "shields-off-menu-icon"), accessory: .disclosureIndicator)
      ],
      uuid: featureSectionUUID.uuidString
    )

//    #if !NO_BRAVE_NEWS
//    section.rows.append(
//      Row(
//        text: Strings.BraveNews.braveNews,
//        selection: {
//          let todaySettings = BraveNewsSettingsViewController(dataSource: self.feedDataSource, rewards: self.rewards)
//          self.navigationController?.pushViewController(todaySettings, animated: true)
//        }, image: #imageLiteral(resourceName: "settings-brave-today").template, accessory: .disclosureIndicator)
//    )
//    #endif

//    section.rows.append(
//      Row(
//        text: Strings.PlayList.playListSectionTitle,
//        selection: { [unowned self] in
//          let playlistSettings = PlaylistSettingsViewController()
//          self.navigationController?.pushViewController(playlistSettings, animated: true)
//        }, image: #imageLiteral(resourceName: "settings-playlist").template, accessory: .disclosureIndicator)
//    )

    return section
  }()

  private lazy var generalSection: Static.Section = {
    var general = Static.Section(
      header: .title(Strings.settingsGeneralSectionTitle),
      rows: [
        Row(
          text: Strings.searchEngines,
          selection: { [unowned self] in
            let viewController = SearchSettingsTableViewController(profile: self.profile)
            self.navigationController?.pushViewController(viewController, animated: true)
          }, image: #imageLiteral(resourceName: "settings-search").template, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
//        Row(
//          text: Strings.sync,
//          selection: { [unowned self] in
//            if syncAPI.isInSyncGroup {
//              if !DeviceInfo.hasConnectivity() {
//                self.present(SyncAlerts.noConnection, animated: true)
//                return
//              }
//
//              self.navigationController?
//                .pushViewController(SyncSettingsTableViewController(syncAPI: syncAPI), animated: true)
//            } else {
//              self.navigationController?.pushViewController(SyncWelcomeViewController(syncAPI: syncAPI), animated: true)
//            }
//          }, image: #imageLiteral(resourceName: "settings-sync").template, accessory: .disclosureIndicator,
//          cellClass: MultilineValue1Cell.self),
        .boolRow(title: Strings.bookmarksLastVisitedFolderTitle, option: Preferences.General.showLastVisitedBookmarksFolder, image: #imageLiteral(resourceName: "menu_folder_open").template),
        Row(
          text: Strings.Shortcuts.shortcutSettingsTitle,
          selection: { [unowned self] in
            self.navigationController?.pushViewController(ShortcutSettingsViewController(), animated: true)
          }, image: #imageLiteral(resourceName: "settings-siri-shortcuts").template, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
      ]
    )

    if UIDevice.isIpad {
      general.rows.append(
        .boolRow(
          title: Strings.alwaysRequestDesktopSite,
          option: Preferences.General.alwaysRequestDesktopSite,
          image: #imageLiteral(resourceName: "settings-desktop-always").template)
      )
    }

    general.rows.append(contentsOf: [
      .boolRow(
        title: Strings.enablePullToRefresh,
        option: Preferences.General.enablePullToRefresh,
        image: #imageLiteral(resourceName: "settings-pull-to-refresh").template),
      .boolRow(
        title: Strings.mediaAutoBackgrounding,
        option: Preferences.General.mediaAutoBackgrounding,
        image: #imageLiteral(resourceName: "background_play_settings_icon").template),
    ])

    return general
  }()

  private lazy var displaySection: Static.Section = {
    var display = Static.Section(
      header: .title(Strings.displaySettingsSection),
      rows: []
    )

    let themeSubtitle = DefaultTheme(rawValue: Preferences.General.themeNormalMode.value)?.displayString
    var row = Row(text: Strings.themesDisplayBrightness, detailText: themeSubtitle, image: #imageLiteral(resourceName: "settings-appearance").template, accessory: .disclosureIndicator, cellClass: MultilineSubtitleCell.self)
    row.selection = { [unowned self] in
      let optionsViewController = OptionSelectionViewController<DefaultTheme>(
        options: DefaultTheme.normalThemesOptions,
        selectedOption: DefaultTheme(rawValue: Preferences.General.themeNormalMode.value),
        optionChanged: { [unowned self] _, option in
          Preferences.General.themeNormalMode.value = option.rawValue
          self.dataSource.reloadCell(row: row, section: display, displayText: option.displayString)
        }
      )
      optionsViewController.headerText = Strings.themesDisplayBrightness
      optionsViewController.footerText = Strings.themesDisplayBrightnessFooter

      let nightModeSection = Section(
        header: .title(Strings.NightMode.sectionTitle.uppercased()),
        rows: [
          .boolRow(
            title: Strings.NightMode.settingsTitle,
            detailText: Strings.NightMode.settingsDescription,
            option: Preferences.General.nightModeEnabled,
            onValueChange: { [unowned self] enabled in
              NightModeHelper.setNightMode(tabManager: tabManager, enabled: enabled)
            },
            image: UIImage(systemName: "moon"))
        ],
        footer: .title(Strings.NightMode.sectionDescription)
      )

      optionsViewController.dataSource.sections.append(nightModeSection)
      self.navigationController?.pushViewController(optionsViewController, animated: true)
    }
    display.rows.append(row)

    if UIDevice.current.userInterfaceIdiom == .pad {
      display.rows.append(
        Row(text: Strings.showTabsBar, image: #imageLiteral(resourceName: "settings-show-tab-bar").template, accessory: .switchToggle(value: Preferences.General.tabBarVisibility.value == TabBarVisibility.always.rawValue, { Preferences.General.tabBarVisibility.value = $0 ? TabBarVisibility.always.rawValue : TabBarVisibility.never.rawValue }), cellClass: MultilineValue1Cell.self)
      )
    } else {
      var row = Row(text: Strings.showTabsBar, detailText: TabBarVisibility(rawValue: Preferences.General.tabBarVisibility.value)?.displayString, image: #imageLiteral(resourceName: "settings-show-tab-bar").template, accessory: .disclosureIndicator, cellClass: MultilineSubtitleCell.self)
      row.selection = { [unowned self] in
        // Show options for tab bar visibility
        let optionsViewController = OptionSelectionViewController<TabBarVisibility>(
          options: TabBarVisibility.allCases,
          selectedOption: TabBarVisibility(rawValue: Preferences.General.tabBarVisibility.value),
          optionChanged: { _, option in
            Preferences.General.tabBarVisibility.value = option.rawValue
            self.dataSource.reloadCell(row: row, section: display, displayText: option.displayString)
          }
        )
        optionsViewController.headerText = Strings.showTabsBar
        self.navigationController?.pushViewController(optionsViewController, animated: true)
      }
      display.rows.append(row)
    }

    let autoCloseSetting =
      Preferences
      .AutoCloseTabsOption(rawValue: Preferences.General.autocloseTabs.value)?.displayString
    var autoCloseTabsRow =
      Row(
        text: Strings.Settings.autocloseTabsSetting,
        detailText: autoCloseSetting, image: #imageLiteral(resourceName: "settings-autoclose-tabs").template,
        accessory: .disclosureIndicator,
        cellClass: MultilineSubtitleCell.self)
    autoCloseTabsRow.selection = { [unowned self] in
      let optionsViewController = OptionSelectionViewController<Preferences.AutoCloseTabsOption>(
        options: Preferences.AutoCloseTabsOption.allCases,
        selectedOption:
          Preferences.AutoCloseTabsOption(rawValue: Preferences.General.autocloseTabs.value),
        optionChanged: { _, option in
          Preferences.General.autocloseTabs.value = option.rawValue
          self.dataSource.reloadCell(row: autoCloseTabsRow, section: display, displayText: option.displayString)
        }
      )
      optionsViewController.headerText = Strings.Settings.autocloseTabsSetting
      optionsViewController.footerText = Strings.Settings.autocloseTabsSettingFooter
      self.navigationController?.pushViewController(optionsViewController, animated: true)
    }

    display.rows.append(autoCloseTabsRow)

    display.rows.append(contentsOf: [
      .boolRow(
        title: Strings.showBookmarkButtonInTopToolbar,
        option: Preferences.General.showBookmarkToolbarShortcut,
        image: #imageLiteral(resourceName: "settings-bookmarks-shortcut").template),
//      .boolRow(
//        title: Strings.hideRewardsIcon,
//        option: Preferences.Rewards.hideRewardsIcon,
//        image: #imageLiteral(resourceName: "settings-rewards-icon").template),
    ])

    return display
  }()

  private var vpnRow: Row?

//  private func vpnSettingsRow() -> Row {
//
//    let (text, color) = { () -> (String, UIColor) in
//      switch BraveVPN.vpnState {
//      case .notPurchased, .purchased:
//        return ("", UIColor.black)
//      case .installed(let enabled):
//        if enabled {
//          return (Strings.VPN.settingsVPNEnabled, .braveSuccessLabel)
//        } else {
//          return (Strings.VPN.settingsVPNDisabled, .braveErrorLabel)
//        }
//      case .expired:
//        return (Strings.VPN.settingsVPNExpired, .braveErrorLabel)
//      }
//    }()
//
//    return Row(
//      text: Strings.VPN.vpnName, detailText: text,
//      selection: { [unowned self] in
//
//        let vc = { () -> UIViewController? in
//          switch BraveVPN.vpnState {
//          case .notPurchased, .purchased, .expired:
//            return BraveVPN.vpnState.enableVPNDestinationVC
//          case .installed:
//            let vc = BraveVPNSettingsViewController()
//            vc.faqButtonTapped = { [weak self] in
//              self?.settingsDelegate?.settingsOpenURLInNewTab(BraveUX.braveVPNFaqURL)
//              self?.dismiss(animated: true)
//            }
//            return vc
//          }
//        }()
//
//        guard let vcToShow = vc else { return }
//        self.navigationController?.pushViewController(vcToShow, animated: true)
//      }, image: #imageLiteral(resourceName: "settings-vpn").template, accessory: .disclosureIndicator,
//      cellClass: ColoredDetailCell.self, context: [ColoredDetailCell.colorKey: color], uuid: "vpnrow")
//  }

  private lazy var securitySection: Static.Section = {
    return Section(
      header: .title(Strings.security),
      rows: [
        .boolRow(title: Strings.browserLock, detailText: Strings.browserLockDescription, option: Preferences.Privacy.lockWithPasscode, image: #imageLiteral(resourceName: "settings-passcode").template),
        Row(
          text: Strings.Login.loginListNavigationTitle,
          selection: { [unowned self] in
            let loginsPasswordsViewController = LoginListViewController(
              passwordAPI: self.passwordAPI,
              windowProtection: self.windowProtection)
            loginsPasswordsViewController.settingsDelegate = self.settingsDelegate
            self.navigationController?.pushViewController(loginsPasswordsViewController, animated: true)
          }, image: #imageLiteral(resourceName: "settings-save-logins").template, accessory: .disclosureIndicator),
      ]
    )
  }()

  private lazy var supportSection: Static.Section = {
    return Static.Section(
      header: .title(Strings.support),
      rows: [
        Row(
          text: Strings.reportABug,
          selection: { [unowned self] in
            self.settingsDelegate?.settingsOpenURLInNewTab(BraveUX.braveCommunityURL)
            self.dismiss(animated: true)
          },
          image: #imageLiteral(resourceName: "settings-report-bug").template,
          cellClass: MultilineValue1Cell.self),
        Row(
          text: Strings.rateBrave,
          selection: { [unowned self] in
            // Rate Presearch
            guard let writeReviewURL = URL(string: "https://itunes.apple.com/app/id1565192485?action=write-review")
            else { return }
            UIApplication.shared.open(writeReviewURL)
            self.dismiss(animated: true)
          },
          image: #imageLiteral(resourceName: "settings-rate").template,
          cellClass: MultilineValue1Cell.self),
        // Mamy - 04/05/20212
          Row(text: Strings.twitterPresearch,
              selection: { [unowned self] in
                // Twitter Presearch
                guard let writeReviewURL = URL(string: "https://twitter.com/presearchnews")
                else { return }
                UIApplication.shared.open(writeReviewURL)
                self.dismiss(animated: true)
              },
              image: #imageLiteral(resourceName: "settings-twitter").template,
              cellClass: MultilineValue1Cell.self),
        Row(text: Strings.telegramPresearch,
            selection: { [unowned self] in
              // Telegran Presearch
              guard let writeReviewURL = URL(string: "https://t.me/presearch")
              else { return }
              UIApplication.shared.open(writeReviewURL)
              self.dismiss(animated: true)
            },
            image: #imageLiteral(resourceName: "settings-telegram").template,
            cellClass: MultilineValue1Cell.self),
        Row(text: Strings.nodesPresearch,
            selection: { [unowned self] in
              // Nodes Presearch
              guard let writeReviewURL = URL(string: "https://nodes.presearch.org")
              else { return }
              UIApplication.shared.open(writeReviewURL)
              self.dismiss(animated: true)
            },
            image: #imageLiteral(resourceName: "settings-node").template,
            cellClass: MultilineValue1Cell.self),
        Row(text: Strings.keywordAdPresearch,
            selection: { [unowned self] in
              // Keyword Advertising Presearch
              guard let writeReviewURL = URL(string: "https://keywords.presearch.org")
              else { return }
              UIApplication.shared.open(writeReviewURL)
              self.dismiss(animated: true)
            },
            image: #imageLiteral(resourceName: "settings-keyboard-ad").template,
            cellClass: MultilineValue1Cell.self)
        // End
      ]
    )
  }()

  private lazy var aboutSection: Static.Section = {
    let version = String(
      format: Strings.versionTemplate,
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
      Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
    let coreVersion = "BraveCore \(BraveCoreVersionInfo.braveCoreVersion) (\(BraveCoreVersionInfo.chromiumVersion))"
    return Static.Section(
      header: .title(Strings.about),
      rows: [
        Row(
          text: version,
          selection: { [unowned self] in
            let device = UIDevice.current
            let actionSheet = UIAlertController(title: version, message: coreVersion, preferredStyle: .actionSheet)
            actionSheet.popoverPresentationController?.sourceView = self.view
            actionSheet.popoverPresentationController?.sourceRect = self.view.bounds
            let iOSVersion = "\(device.systemName) \(UIDevice.current.systemVersion)"

            let deviceModel = String(format: Strings.deviceTemplate, device.modelName, iOSVersion)
            let copyDebugInfoAction = UIAlertAction(title: Strings.copyAppInfoToClipboard, style: .default) { _ in
              UIPasteboard.general.strings = [version, coreVersion, deviceModel]
            }

            actionSheet.addAction(copyDebugInfoAction)
            actionSheet.addAction(UIAlertAction(title: Strings.cancelButtonTitle, style: .cancel, handler: nil))
            self.navigationController?.present(actionSheet, animated: true, completion: nil)
          }, cellClass: MultilineValue1Cell.self),
        Row(text: Strings.privacyPolicy,
            selection: { [unowned self] in
              // Show privacy policy
              let privacy = SettingsContentViewController().then { $0.url = BraveUX.bravePrivacyURL }
              self.navigationController?.pushViewController(privacy, animated: true)
            },
            accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: Strings.termsOfUse,
          selection: { [unowned self] in
            // Show terms of use
            let toc = SettingsContentViewController().then { $0.url = BraveUX.braveTermsOfUseURL }
            self.navigationController?.pushViewController(toc, animated: true)
          },
          accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: Strings.settingsLicenses,
          selection: { [unowned self] in
            let licenses = SettingsContentViewController().then {
              $0.url = URL(string: "\(InternalURL.baseUrl)/\(AboutLicenseHandler.path)")
            }
            self.navigationController?.pushViewController(licenses, animated: true)
          }, accessory: .disclosureIndicator),
      ]
    )
  }()

  private lazy var debugSection: Static.Section? = {
    if AppConstants.buildChannel.isPublic { return nil }

    return Static.Section(
      rows: [
        Row(text: "Region: \(Locale.current.regionCode ?? "--")"),
        Row(
          text: "Sandbox Inspector",
          selection: { [unowned self] in
            let vc = UIHostingController(rootView: SandboxInspectorView())
            self.navigationController?.pushViewController(vc, animated: true)
          }, accessory: .disclosureIndicator),
        Row(
          text: "Adblock Debug",
          selection: { [unowned self] in
            let vc = AdblockDebugMenuTableViewController(style: .grouped)
            self.navigationController?.pushViewController(vc, animated: true)
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: "View URP Logs",
          selection: { [unowned self] in
            self.navigationController?.pushViewController(UrpLogsViewController(), animated: true)
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(text: "URP Code: \(UserReferralProgram.getReferralCode() ?? "--")"),
        Row(
          text: "BraveCore Switches",
          selection: { [unowned self] in
            let controller = UIHostingController(rootView: BraveCoreDebugSwitchesView())
            self.navigationController?.pushViewController(controller, animated: true)
          }, accessory: .disclosureIndicator, cellClass: MultilineSubtitleCell.self),
        Row(
          text: "View Rewards Debug Menu",
          selection: { [unowned self] in
            self.displayRewardsDebugMenu()
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: "View Presearch News Debug Menu",
          selection: { [unowned self] in
            self.displayBraveNewsDebugMenu()
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: "View Presearch Search Debug Menu",
          selection: { [unowned self] in
            self.displayBraveSearchDebugMenu()
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: "VPN Logs",
          selection: { [unowned self] in
            self.navigationController?.pushViewController(VPNLogsViewController(), animated: true)
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: "Retention Preferences Debug Menu",
          selection: { [unowned self] in
            self.navigationController?.pushViewController(RetentionPreferencesDebugMenuViewController(), animated: true)
          }, accessory: .disclosureIndicator, cellClass: MultilineValue1Cell.self),
        Row(
          text: "Load all QA Links",
          selection: { [unowned self] in
            let url = URL(string: "https://raw.githubusercontent.com/brave/qa-resources/master/testlinks.json")!
            let string = try? String(contentsOf: url)
            let urls = JSON(parseJSON: string!)["links"].arrayValue.compactMap { URL(string: $0.stringValue) }
            self.settingsDelegate?.settingsOpenURLs(urls)
            self.dismiss(animated: true)
          }, cellClass: MultilineButtonCell.self),
        Row(
          text: "CRASH!!!",
          selection: { [unowned self] in
            let alert = UIAlertController(title: "Force crash?", message: nil, preferredStyle: .alert)
            alert.addAction(
              UIAlertAction(title: "Crash app", style: .destructive) { _ in
                fatalError()
              })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
          }, cellClass: MultilineButtonCell.self),
      ]
    )
  }()

  private func setUpSections() {
    if let settingsStore = walletSettingsStore, let networkStore = walletNetworkStore, let keyringStore = keyringStore {
      settingsStore.isDefaultKeyringCreated { [weak self] created in
        guard let self = self else { return }
        var copyOfSections = self.sections
        if let featureSectionIndex = self.sections.firstIndex(where: {
          $0.uuid == self.featureSectionUUID.uuidString
        }) {
          let walletRowIndex = copyOfSections[featureSectionIndex].rows.firstIndex(where: {
            $0.uuid == self.walletRowUUID.uuidString
          })
          if created, walletRowIndex == nil {
            settingsStore.addKeyringServiceObserver(self)
//            Mamy - 2022
//            copyOfSections[featureSectionIndex].rows.append(
//              Row(
//                text: Strings.Wallet.braveWallet,
//                selection: { [unowned self] in
//                  let walletSettingsView = WalletSettingsView(
//                    settingsStore: settingsStore,
//                    networkStore: networkStore,
//                    keyringStore: keyringStore
//                  )
//                  let vc = UIHostingController(rootView: walletSettingsView)
//                  self.navigationController?.pushViewController(vc, animated: true)
//                },
//                image: #imageLiteral(resourceName: "menu-crypto").template,
//                accessory: .disclosureIndicator,
//                uuid: self.walletRowUUID.uuidString)
//            )
          } else if !created, let index = walletRowIndex {
            copyOfSections.remove(at: index)
          }
        }
        self.dataSource.sections = copyOfSections
      }
    }
  }

  // MARK: - Actions

//  private func enableVPNTapped() {
//    let state = BraveVPN.vpnState
//
//    switch state {
//    case .notPurchased, .purchased, .expired:
//      guard let vc = state.enableVPNDestinationVC else { return }
//      navigationController?.pushViewController(vc, animated: true)
//    case .installed:
//      BraveVPN.reconnect()
//      dismiss(animated: true)
//    }
//  }

  private func dismissVPNHeaderTapped() {
    if dataSource.sections.isEmpty { return }
    dataSource.sections[0] = Static.Section()
    Preferences.VPN.vpnSettingHeaderWasDismissed.value = true
  }
}

extension SettingsViewController: BraveWalletKeyringServiceObserver {
  func keyringCreated(_ keyringId: String) {}
  func keyringRestored(_ keyringId: String) {}
  func locked() {}
  func unlocked() {}
  func backedUp() {}
  func accountsChanged() {}
  func autoLockMinutesChanged() {}
  func selectedAccountChanged(_ coin: BraveWallet.CoinType) {}

  func keyringReset() {
    setUpSections()
    navigationController?.popViewController(animated: true)
  }
}
