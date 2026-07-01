// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import XCTest
@testable import Client

class DomainUserScriptTests: XCTestCase {

  func testPresearchNSFWHideAvailability() throws {
    let goodURLs = [
      URL(string: "https://presearch.com"),
      URL(string: "https://presearch.io"),
      URL(string: "https://presearch.org"),
      URL(string: "https://subdomain.presearch.com/custom/path"),
    ].compactMap { $0 }

    goodURLs.forEach {
      XCTAssertEqual(DomainUserScript(for: $0), .presearchNSFWHide)
    }

    let badURLs = [
      URL(string: "https://search.brave.software.com"),
      URL(string: "https://community.brave.com"),
      URL(string: "https://brave.com"),
      URL(string: "https://presearch.example.com"),
    ].compactMap { $0 }

    badURLs.forEach {
      XCTAssertNotEqual(DomainUserScript(for: $0), .presearchNSFWHide)
    }
  }

  func testYouTubeAdBlockAvailability() throws {
    let goodURLs = [
      URL(string: "https://youtube.com")!,
      URL(string: "https://www.youtube.com")!
    ]

    goodURLs.forEach {
      XCTAssertEqual(DomainUserScript(for: $0), .youtubeAdBlock)
    }

    let badURLs = [
      URL(string: "https://youtube.org.com")!,
      URL(string: "https://www.youtube.org.com")!,
      URL(string: "https://metube.com")!
    ]

    badURLs.forEach {
      XCTAssertNotEqual(DomainUserScript(for: $0), .youtubeAdBlock)
    }
  }
}
