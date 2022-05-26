// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Shared
import BraveShared
import WebKit

private let log = Logger.browserLogger

enum DomainUserScript: CaseIterable {
  case youtubeAdBlock
  case archive

  /// Initialize this script with a URL
  init?(for url: URL) {
    // First we look for an exact domain match
    if let host = url.host, let found = Self.allCases.first(where: { $0.associatedDomains.contains(host) }) {
      self = found
      return
    }

    // If no matches, we look for a baseDomain (eTLD+1) match.
    if let baseDomain = url.baseDomain, let found = Self.allCases.first(where: { $0.associatedDomains.contains(baseDomain) }) {
      self = found
      return
    }

    return nil
  }

  /// Returns a shield type for a given user script domain.
  /// Returns nil if the domain's user script can't be turned off via a shield toggle. (i.e. it's always enabled)
  var shieldType: BraveShield? {
    switch self {
    case .youtubeAdBlock:
      return .AdblockAndTp
    case .archive:
      return nil
    }
  }

  /// The domains associated with this script.
  var associatedDomains: Set<String> {
    switch self {
    case .youtubeAdBlock:
      return Set(arrayLiteral: "youtube.com")
    case .archive:
      return Set(arrayLiteral: "archive.is", "archive.today", "archive.vn", "archive.fo")
    }
  }
}
