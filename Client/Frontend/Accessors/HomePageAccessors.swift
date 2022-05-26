/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import XCGLogger

/// Accessors for homepage details from the app state.
/// These are pure functions, so it's quite ok to have them
/// as static.
class HomePageAccessors {

  static func getHomePage(_ prefs: Prefs) -> URL? {
    let urlString = "https://presearch.com/search"
    return NSURL(string: urlString) as URL?
  }
}
