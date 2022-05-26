// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import XCTest
@testable import Client

class UniversalLinkManagerTests: XCTestCase {
  private typealias ULM = UniversalLinkManager

  func testVpnUniversalLink() throws {
    // Good cases
    [
      "https://vpn.presearch.io/dl/test": true,
      "https://vpn.presearch.io/dl/test2": false,
      "http://vpn.presearch.io/dl/test3": true,
      "https://vpn.presearch.io/dl/test/123": true,
      "https://vpn.presearch.io/path/does/not/matter": false,
    ]
    .forEach {
      XCTAssertEqual(
        ULM.LinkType.buyVPN,
        ULM.universalLinkType(for: URL(string: $0.key)!, checkPath: $0.value))
    }

    // Bad cases
    [
      "https://vpn.presearch.io/bad/dl/test/123": true,
      "https://presearch.io/dl/test": true,
      "https://example.com": false,
      "https://example.com/dl/test": true,
      "https://vpn.presearch.io/dl": true,
      "https://vpn.presearch.io/dlonger/test": true,
    ]
    .forEach {
      XCTAssertNil(ULM.universalLinkType(for: URL(string: $0.key)!, checkPath: $0.value))
    }
  }
}
